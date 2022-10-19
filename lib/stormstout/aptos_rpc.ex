defmodule Stormstout.AptosRPC do
  @moduledoc false

  defstruct [:endpoint, :client, :chain_id]

  # @endpoint "https://fullnode.devnet.aptoslabs.com/v1"
  # @endpoint "https://testnet.aptoslabs.com/v1"
  @endpoint "https://fullnode.mainnet.aptoslabs.com/v1"

  def connect(endpoint \\ @endpoint) do
    client =
      Tesla.client([
        # TODO: convert input/output type
        {Tesla.Middleware.BaseUrl, endpoint},
        # {Tesla.Middleware.Headers, [{"content-type", "application/json"}]},
        {Tesla.Middleware.JSON, engine_opts: [keys: :atoms]}
      ])

    rpc = %__MODULE__{client: client, endpoint: endpoint}

    with {:ok, %{chain_id: chain_id}} <- ledger_information(rpc) do
      {:ok, %{rpc | endpoint: endpoint, chain_id: chain_id}}
    end
  end

  defp get(%{client: client}, path, options \\ []) do
    with {:ok, %{status: 200, body: resp_body}} <- Tesla.get(client, path, options) do
      {:ok, resp_body}
    else
      {:ok, %{body: resp_body}} -> {:error, resp_body}
      {:error, error} -> {:error, error}
    end
  end

  defp post(%{client: client}, path, body, options \\ []) do
    with {:ok, %{body: resp_body}} <- Tesla.post(client, path, body, options) do
      case resp_body do
        %{code: _, message: message} -> {:error, message}
        _ -> {:ok, resp_body}
      end
    else
      {:error, error} -> {:error, error}
    end
  end

  # Chain
  def ledger_information(client) do
    get(client, "/")
  end

  # Accounts
  def get_account(client, address) do
    get(client, "/accounts/#{address}")
  end

  def get_account_resources(client, address, query \\ []) do
    get(client, "/accounts/#{address}/resources", query: query)
  end

  def get_account_resource(client, address, resource_type, query \\ []) do
    get(client, "/accounts/#{address}/resource/#{resource_type}", query: query)
  end

  # Transactions
  def get_transaction_by_hash(client, hash) do
    get(client, "/transactions/by_hash/#{hash}")
  end

  def check_transaction_by_hash(client, hash, times \\ 3) do
    case get_transaction_by_hash(client, hash) do
      {:ok, result} ->
        result.success

      {:error, _} ->
        if times > 0 do
          Process.sleep(1000)
          check_transaction_by_hash(client, hash, times - 1)
        else
          false
        end
    end
  end

  # Events
  def get_events(client, event_key) do
    case get(client, "/events/#{event_key}") do
      {:ok, event_list} -> {:ok, event_list}
      {:error, %{error_code: "resource_not_found"}} -> {:ok, []}
    end
  end

  def get_events(client, address, event_handle, field, query \\ [limit: 10]) do
    case get(client, "/accounts/#{address}/events/#{event_handle}/#{field}", query: query) do
      {:ok, event_list} -> {:ok, event_list}
      {:error, %{error_code: "resource_not_found"}} -> {:ok, []}
    end
  end

  # Table
  def get_table_item(client, table_handle, table_key) do
    post(client, "/tables/#{table_handle}/item", table_key)
  end

  # Tokens
  def get_token_data(client, creator, collection_name, token_name) do
    with {:ok, result} <- get_account_resource(client, creator, "0x3::token::Collections") do
      %{handle: handle} = result.data.token_data

      token_data_id = %{
        creator: creator,
        collection: collection_name,
        name: token_name
      }

      table_key = %{
        key_type: "0x3::token::TokenDataId",
        value_type: "0x3::token::TokenData",
        key: token_data_id
      }

      get_table_item(client, handle, table_key)
    end
  end

  def get_collection_data(client, account, collection_name) do
    with {:ok, result} <- get_account_resource(client, account, "0x3::token::Collections") do
      %{handle: handle} = result.data.collection_data

      table_key = %{
        key_type: "0x1::string::String",
        value_type: "0x3::token::CollectionData",
        key: collection_name
      }

      {:ok, result} = get_table_item(client, handle, table_key)

      case result do
        %{error_code: _} -> {:error, result}
        _ -> {:ok, result}
      end
    else
      _ -> {:error, "Token data not found"}
    end
  end
end
