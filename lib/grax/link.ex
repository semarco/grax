defmodule Grax.Link.NotLoaded do
  @moduledoc !"""
             Struct returned by links when they are not loaded.

             The fields are:

               * `__field__` - the link field in `owner`
               * `__owner__` - the schema that owns the link
             """

  @type t :: %__MODULE__{
          __field__: atom(),
          __owner__: any()
        }

  defstruct [:__field__, :__owner__]

  defimpl Inspect do
    def inspect(not_loaded, _opts) do
      msg = "link #{inspect(not_loaded.__field__)} is not loaded"
      ~s(#Grax.Link.NotLoaded<#{msg}>)
    end
  end
end

defmodule Grax.Link.Preloader do
  @moduledoc false

  alias RDF.{Description, Graph, Query}
  alias Grax.Schema.Type

  import RDF.Utils

  @default {:depth, 1}

  def default, do: @default

  def call(mapping_mod, mapping, graph, opts) do
    description = Graph.description(graph, mapping.__id__) || Description.new(mapping.__id__)
    call(mapping_mod, mapping, graph, description, opts)
  end

  def call(mapping_mod, mapping, graph, description, opts) do
    graph_load_path = Keyword.get(opts, :__graph_load_path__, [])
    depth = length(graph_load_path)
    graph_load_path = [mapping.__id__ | graph_load_path]
    opts = Keyword.put(opts, :__graph_load_path__, graph_load_path)
    link_schemas = mapping_mod.__properties__(:link)

    Enum.reduce_while(link_schemas, {:ok, mapping}, fn {link, link_schema}, {:ok, mapping} ->
      {preload?, next_preload_opt, max_preload_depth} =
        next_preload_opt(
          Keyword.get(opts, :preload),
          link_schema.preload,
          mapping_mod,
          link,
          depth,
          Keyword.get(opts, :__max_preload_depth__)
        )

      if preload? do
        objects = objects(graph, description, link_schema.iri)

        cond do
          is_nil(objects) ->
            {:cont,
             {:ok, Map.put(mapping, link, if(Type.set?(link_schema.type), do: [], else: nil))}}

          # The circle check is not needed when preload opts are given as there finite depth
          # overwrite any additive preload depths by properties which may cause infinite preloads
          is_nil(next_preload_opt) and circle?(objects, graph_load_path) ->
            {:cont, {:ok, mapping}}

          true ->
            opts =
              if next_preload_opt do
                Keyword.put(opts, :preload, next_preload_opt)
              else
                opts
              end
              |> Keyword.put(:__max_preload_depth__, max_preload_depth)

            handle(link, objects, description, graph, link_schema, opts)
            |> case do
              {:ok, mapped_objects} ->
                {:cont, {:ok, Map.put(mapping, link, mapped_objects)}}

              {:error, _} = error ->
                {:halt, error}
            end
        end
      else
        {:cont, {:ok, mapping}}
      end
    end)
  end

  defp objects(graph, description, {:inverse, property_iri}) do
    {:object?, property_iri, description.subject}
    |> Query.execute!(graph)
    |> case do
      [] -> nil
      results -> Enum.map(results, &Map.fetch!(&1, :object))
    end
  end

  defp objects(_graph, description, property_iri) do
    Description.get(description, property_iri)
  end

  def next_preload_opt(nil, nil, mapping_mod, link, depth, max_depth) do
    next_preload_opt(
      nil,
      mapping_mod.__preload_default__() || @default,
      mapping_mod,
      link,
      depth,
      max_depth
    )
  end

  def next_preload_opt(nil, {:depth, max_depth}, _mapping_mod, _link, 0, _max_depth) do
    {max_depth > 0, nil, max_depth}
  end

  def next_preload_opt(nil, {:depth, _}, _mapping_mod, _link, depth, max_depth) do
    {max_depth - depth > 0, nil, max_depth}
  end

  def next_preload_opt(nil, {:add_depth, add_depth}, _mapping_mod, _link, depth, _max_depth) do
    new_depth = depth + add_depth
    {new_depth - depth > 0, nil, new_depth}
  end

  def next_preload_opt(nil, depth, _mapping_mod, _link, _depth, _max_depth),
    do: raise(ArgumentError, "invalid depth: #{inspect(depth)}")

  def next_preload_opt(
        {:depth, max_depth} = depth_tuple,
        preload_spec,
        mapping_mod,
        _link,
        depth,
        parent_max_depth
      ) do
    {max_depth - depth > 0, depth_tuple,
     max_depth(parent_max_depth, preload_spec, mapping_mod, depth)}
  end

  def next_preload_opt(
        {:add_depth, add_depth},
        preload_spec,
        mapping_mod,
        _link,
        depth,
        parent_max_depth
      ) do
    new_depth = depth + add_depth

    {new_depth - depth > 0, {:depth, new_depth},
     max_depth(new_depth, preload_spec, mapping_mod, depth)}
  end

  defp max_depth(_, {:depth, max_depth}, _, 0), do: max_depth
  defp max_depth(_, {:add_depth, add_depth}, _, depth), do: depth + add_depth
  defp max_depth(max_depth, _, _, _) when is_integer(max_depth), do: max_depth

  defp max_depth(nil, nil, mapping_mod, depth),
    do: max_depth(nil, mapping_mod.__preload_default__() || @default, nil, depth)

  defp circle?(objects, graph_load_path) do
    Enum.any?(objects, &(&1 in graph_load_path))
  end

  defp handle(property, objects, description, graph, property_schema, opts)

  defp handle(_property, objects, _description, graph, property_schema, opts) do
    map_links(objects, property_schema.type, property_schema, graph, opts)
  end

  defp map_links(values, {:set, type}, property_schema, graph, opts) do
    map_while_ok(values, &map_link(&1, type, property_schema, graph, opts))
  end

  defp map_links([value], type, property_schema, graph, opts) do
    map_link(value, type, property_schema, graph, opts)
  end

  defp map_links(values, type, property_schema, graph, opts) do
    map_while_ok(values, &map_link(&1, type, property_schema, graph, opts))
  end

  defp map_link(resource, {:resource, module}, property_schema, graph, opts) do
    module.load(graph, resource, opts)
  end
end
