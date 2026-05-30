defmodule SquadOps.Azure.Client do
  @moduledoc """
  HTTP client for Azure DevOps REST API.

  Builds a Req struct already authenticated with the PAT (Personal Access Token)
  using Basic auth (empty username, PAT as password — Azure convention).
  """

  alias SquadOps.Auth.Token

  @api_version "7.1"

  def new(%Token{pat_token: pat, azure_org_url: org_url}) do
    Req.new(
      base_url: String.trim_trailing(org_url, "/"),
      auth: {:basic, ":" <> pat},
      headers: [{"accept", "application/json"}],
      receive_timeout: 30_000,
      params: ["api-version": @api_version]
    )
  end

  def get(req, path, opts \\ []), do: Req.get(req, [url: path] ++ opts)
  def post(req, path, body, opts \\ []), do: Req.post(req, [url: path, json: body] ++ opts)

  def handle({:ok, %Req.Response{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  def handle({:ok, %Req.Response{status: 401}}), do: {:error, :unauthorized}
  def handle({:ok, %Req.Response{status: 404}}), do: {:error, :not_found}
  def handle({:ok, %Req.Response{status: 429}}), do: {:error, :rate_limited}
  def handle({:ok, %Req.Response{status: status, body: body}}), do: {:error, {status, body}}
  def handle({:error, exception}), do: {:error, {:transport, Exception.message(exception)}}
end
