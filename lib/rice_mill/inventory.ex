defmodule RiceMill.Inventory do
  @moduledoc """
  The Inventory context.
  """

  import Ecto.Query, warn: false
  alias RiceMill.Repo
  alias RiceMill.Inventory.Product
  alias RiceMill.Inventory.StockIn
  alias RiceMill.Inventory.StockOut

  @doc """
  Returns the list of products for a given tenant.

  ## Examples

      iex> list_products(tenant_id)
      [%Product{}, ...]

  """
  def list_products(tenant_id) when is_nil(tenant_id) do
    # Super admin with no tenant - return empty list or all products
    # For now, return empty list as super admin shouldn't manage products
    []
  end

  def list_products(tenant_id) do
    Product
    |> where([p], p.tenant_id == ^tenant_id)
    |> order_by([p], p.name)
    |> Repo.all()
  end

  @doc """
  Gets a single product for a given tenant.

  Raises `Ecto.NoResultsError` if the Product does not exist or doesn't belong to the tenant.

  ## Examples

      iex> get_product!(tenant_id, 123)
      %Product{}

      iex> get_product!(tenant_id, 456)
      ** (Ecto.NoResultsError)

  """
  def get_product!(tenant_id, _id) when is_nil(tenant_id) do
    raise Ecto.NoResultsError, queryable: Product
  end

  def get_product!(tenant_id, id) do
    Product
    |> where([p], p.tenant_id == ^tenant_id and p.id == ^id)
    |> Repo.one!()
  end

  @doc """
  Creates a product.

  ## Examples

      iex> create_product(tenant_id, %{field: value})
      {:ok, %Product{}}

      iex> create_product(tenant_id, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_product(tenant_id, attrs \\ %{}) do
    attrs_with_tenant = Map.put(attrs, "tenant_id", tenant_id)

    result =
      %Product{}
      |> Product.changeset(attrs_with_tenant)
      |> Repo.insert()

    case result do
      {:ok, product} ->
        broadcast_product_updated(tenant_id, product)
        {:ok, product}

      error ->
        error
    end
  end

  @doc """
  Updates a product. The category field is locked and cannot be changed.

  ## Examples

      iex> update_product(product, %{field: new_value})
      {:ok, %Product{}}

      iex> update_product(product, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_product(%Product{} = product, attrs) do
    result =
      product
      |> Product.update_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_product} ->
        broadcast_product_updated(product.tenant_id, updated_product)
        {:ok, updated_product}

      error ->
        error
    end
  end

  @doc """
  Deletes a product.

  ## Examples

      iex> delete_product(product)
      {:ok, %Product{}}

      iex> delete_product(product)
      {:error, %Ecto.Changeset{}}

  """
  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking product changes.

  ## Examples

      iex> change_product(product)
      %Ecto.Changeset{data: %Product{}}

  """
  def change_product(%Product{} = product, attrs \\ %{}) do
    # Use regular changeset for new products (to include tenant_id)
    # Use update_changeset for existing products
    if product.id do
      Product.update_changeset(product, attrs)
    else
      Product.changeset(product, attrs)
    end
  end

  ## Stock-In functions

  @doc """
  Returns the list of stock-in entries for a given tenant with optional filters.

  ## Examples

      iex> list_stock_ins(tenant_id)
      [%StockIn{}, ...]

      iex> list_stock_ins(tenant_id, %{date_from: ~D[2024-01-01], farmer_name: "John"})
      [%StockIn{}, ...]

  """
  def list_stock_ins(tenant_id, filters \\ %{})

  def list_stock_ins(tenant_id, _filters) when is_nil(tenant_id) do
    # Super admin with no tenant - return empty list
    []
  end

  def list_stock_ins(tenant_id, filters) do
    StockIn
    |> where([s], s.tenant_id == ^tenant_id)
    |> apply_stock_in_filters(filters)
    |> order_by([s], desc: s.date, desc: s.inserted_at)
    |> preload(:product)
    |> Repo.all()
  end

  defp apply_stock_in_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:date_from, date}, query when not is_nil(date) ->
        where(query, [s], s.date >= ^date)

      {:date_to, date}, query when not is_nil(date) ->
        where(query, [s], s.date <= ^date)

      {:farmer_name, name}, query when not is_nil(name) and name != "" ->
        where(query, [s], ilike(s.farmer_name, ^"%#{name}%"))

      _, query ->
        query
    end)
  end

  @doc """
  Gets a single stock-in entry for a given tenant.

  Raises `Ecto.NoResultsError` if the StockIn does not exist or doesn't belong to the tenant.

  ## Examples

      iex> get_stock_in!(tenant_id, 123)
      %StockIn{}

      iex> get_stock_in!(tenant_id, 456)
      ** (Ecto.NoResultsError)

  """
  def get_stock_in!(tenant_id, _id) when is_nil(tenant_id) do
    raise Ecto.NoResultsError, queryable: StockIn
  end

  def get_stock_in!(tenant_id, id) do
    StockIn
    |> where([s], s.tenant_id == ^tenant_id and s.id == ^id)
    |> preload(:product)
    |> Repo.one!()
  end

  @doc """
  Creates a stock-in entry with automatic calculations for total_quintals and total_price.

  ## Examples

      iex> create_stock_in(tenant_id, %{field: value})
      {:ok, %StockIn{}}

      iex> create_stock_in(tenant_id, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_stock_in(tenant_id, attrs \\ %{}) do
    attrs_with_tenant = Map.put(attrs, "tenant_id", tenant_id)

    result =
      %StockIn{}
      |> StockIn.changeset(attrs_with_tenant)
      |> calculate_totals()
      |> Repo.insert()

    case result do
      {:ok, stock_in} ->
        broadcast_transaction_created(tenant_id, stock_in)
        {:ok, stock_in}

      error ->
        error
    end
  end

  @doc """
  Calculates total_quintals and total_price for a stock-in changeset.

  Formula:
  - total_quintals = (num_of_bags * net_weight_per_bag_kg) / 100
  - total_price = total_quintals * price_per_quintal

  ## Examples

      iex> calculate_totals(changeset)
      %Ecto.Changeset{}

  """
  def calculate_totals(changeset) do
    num_of_bags = Ecto.Changeset.get_field(changeset, :num_of_bags)
    net_weight_per_bag_kg = Ecto.Changeset.get_field(changeset, :net_weight_per_bag_kg)
    price_per_quintal = Ecto.Changeset.get_field(changeset, :price_per_quintal)

    if num_of_bags && net_weight_per_bag_kg && price_per_quintal do
      total_quintals = Decimal.div(Decimal.mult(num_of_bags, net_weight_per_bag_kg), 100)
      total_price = Decimal.mult(total_quintals, price_per_quintal)

      changeset
      |> Ecto.Changeset.put_change(:total_quintals, total_quintals)
      |> Ecto.Changeset.put_change(:total_price, total_price)
    else
      changeset
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stock-in changes.

  ## Examples

      iex> change_stock_in(stock_in)
      %Ecto.Changeset{data: %StockIn{}}

  """
  def change_stock_in(%StockIn{} = stock_in, attrs \\ %{}) do
    stock_in
    |> StockIn.changeset(attrs)
    |> calculate_totals()
  end

  ## Stock-Out functions

  @doc """
  Returns the list of stock-out entries for a given tenant with optional filters.

  ## Examples

      iex> list_stock_outs(tenant_id)
      [%StockOut{}, ...]

      iex> list_stock_outs(tenant_id, %{date_from: ~D[2024-01-01], customer_name: "John"})
      [%StockOut{}, ...]

  """
  def list_stock_outs(tenant_id, filters \\ %{})

  def list_stock_outs(tenant_id, _filters) when is_nil(tenant_id) do
    # Super admin with no tenant - return empty list
    []
  end

  def list_stock_outs(tenant_id, filters) do
    StockOut
    |> where([s], s.tenant_id == ^tenant_id)
    |> apply_stock_out_filters(filters)
    |> order_by([s], desc: s.date, desc: s.inserted_at)
    |> preload(:product)
    |> Repo.all()
  end

  defp apply_stock_out_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:date_from, date}, query when not is_nil(date) ->
        where(query, [s], s.date >= ^date)

      {:date_to, date}, query when not is_nil(date) ->
        where(query, [s], s.date <= ^date)

      {:customer_name, name}, query when not is_nil(name) and name != "" ->
        where(query, [s], ilike(s.customer_name, ^"%#{name}%"))

      _, query ->
        query
    end)
  end

  @doc """
  Gets a single stock-out entry for a given tenant.

  Raises `Ecto.NoResultsError` if the StockOut does not exist or doesn't belong to the tenant.

  ## Examples

      iex> get_stock_out!(tenant_id, 123)
      %StockOut{}

      iex> get_stock_out!(tenant_id, 456)
      ** (Ecto.NoResultsError)

  """
  def get_stock_out!(tenant_id, _id) when is_nil(tenant_id) do
    raise Ecto.NoResultsError, queryable: StockOut
  end

  def get_stock_out!(tenant_id, id) do
    StockOut
    |> where([s], s.tenant_id == ^tenant_id and s.id == ^id)
    |> preload(:product)
    |> Repo.one!()
  end

  @doc """
  Creates a stock-out entry with automatic calculations for total_quintals and total_price.

  ## Examples

      iex> create_stock_out(tenant_id, %{field: value})
      {:ok, %StockOut{}}

      iex> create_stock_out(tenant_id, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_stock_out(tenant_id, attrs \\ %{}) do
    attrs_with_tenant = Map.put(attrs, "tenant_id", tenant_id)

    result =
      %StockOut{}
      |> StockOut.changeset(attrs_with_tenant)
      |> calculate_stock_out_totals()
      |> Repo.insert()

    case result do
      {:ok, stock_out} ->
        broadcast_transaction_created(tenant_id, stock_out)
        {:ok, stock_out}

      error ->
        error
    end
  end

  @doc """
  Calculates total_quintals and total_price for a stock-out changeset.

  Formula:
  - total_quintals = (num_of_bags * net_weight_per_bag_kg) / 100
  - total_price = total_quintals * price_per_quintal

  ## Examples

      iex> calculate_stock_out_totals(changeset)
      %Ecto.Changeset{}

  """
  def calculate_stock_out_totals(changeset) do
    num_of_bags = Ecto.Changeset.get_field(changeset, :num_of_bags)
    net_weight_per_bag_kg = Ecto.Changeset.get_field(changeset, :net_weight_per_bag_kg)
    price_per_quintal = Ecto.Changeset.get_field(changeset, :price_per_quintal)

    if num_of_bags && net_weight_per_bag_kg && price_per_quintal do
      total_quintals = Decimal.div(Decimal.mult(num_of_bags, net_weight_per_bag_kg), 100)
      total_price = Decimal.mult(total_quintals, price_per_quintal)

      changeset
      |> Ecto.Changeset.put_change(:total_quintals, total_quintals)
      |> Ecto.Changeset.put_change(:total_price, total_price)
    else
      changeset
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stock-out changes.

  ## Examples

      iex> change_stock_out(stock_out)
      %Ecto.Changeset{data: %StockOut{}}

  """
  def change_stock_out(%StockOut{} = stock_out, attrs \\ %{}) do
    stock_out
    |> StockOut.changeset(attrs)
    |> calculate_stock_out_totals()
  end

  ## PubSub Broadcasting

  defp broadcast_transaction_created(tenant_id, transaction) do
    # Invalidate dashboard cache when transactions are created
    RiceMill.Dashboard.invalidate_cache(tenant_id)

    Phoenix.PubSub.broadcast(
      RiceMill.PubSub,
      "tenant:#{tenant_id}:transactions",
      {:transaction_created, transaction}
    )
  end

  defp broadcast_product_updated(tenant_id, product) do
    # Invalidate dashboard cache when products are updated
    RiceMill.Dashboard.invalidate_cache(tenant_id)

    Phoenix.PubSub.broadcast(
      RiceMill.PubSub,
      "tenant:#{tenant_id}:products",
      {:product_updated, product}
    )
  end
end
