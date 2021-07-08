defmodule Grax.Id.Counter.Dets do
  use GenServer

  @behaviour Grax.Id.Counter.Adapter

  @default_value 0

  def start_link(name, opts \\ []) do
    GenServer.start_link(__MODULE__, {name, opts}, name: name)
  end

  @impl true
  def init({name, opts}) do
    name
    |> table_name()
    |> :dets.open_file(
      type: :set,
      file: name |> file_path(opts) |> to_charlist(),
      repair: true
    )
    |> case do
      {:ok, table_name} ->
        :dets.insert_new(table_name, {:value, @default_value})
        {:ok, name}

      error ->
        error
    end
  end

  @impl true
  def terminate(_reason, counter_name) do
    counter_name
    |> table_name()
    |> :dets.close()

    :normal
  end

  @impl true
  def value(counter) do
    counter
    |> table_name
    |> :dets.lookup(:value)
    |> case do
      [value: value] -> {:ok, value}
      [] -> {:error, "missing counter in DETS table #{table_name(counter)}"}
    end
  end

  @impl true
  def inc(counter) do
    {:ok,
     counter
     |> table_name
     |> :dets.update_counter(:value, {2, 1})}
  end

  @impl true
  def reset(counter, value \\ @default_value) do
    counter
    |> table_name
    |> :dets.insert({:value, value})
  end

  def table_name(counter_name), do: Module.concat(__MODULE__, counter_name)

  def file_path(counter_name, opts \\ []) do
    path = Keyword.get(opts, :path, Grax.Id.Counter.default_counter_dir())
    File.mkdir_p!(path)
    Path.join(path, Atom.to_string(counter_name) <> ".dets")
  end
end
