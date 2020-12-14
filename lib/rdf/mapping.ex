defmodule RDF.Mapping do
  alias RDF.Mapping.{Schema, Link, Loader, Validation, ToRDF}
  alias RDF.{IRI, Graph, Description}

  defmacro __using__(opts) do
    preload_default = Link.Preloader.normalize_spec(Keyword.get(opts, :preload), true)

    quote do
      import Schema, only: [schema: 1, schema: 2]

      @before_compile unquote(__MODULE__)

      @rdf_mapping_preload_default unquote(preload_default)
      def __preload_default__(), do: @rdf_mapping_preload_default
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      defp __new__(iri) do
        %__MODULE__{__iri__: IRI.to_string(iri)}
      end

      @spec iri(struct) :: IRI.t()
      def iri(%__MODULE__{} = mapping), do: mapping.__iri__

      @spec load(Graph.t() | Description.t(), IRI.coercible(), opts :: Keyword) ::
              {:ok, struct} | {:error, any}
      def load(graph, iri, opts \\ []) do
        case __new__(iri) do
          %__MODULE__{} = initial ->
            Loader.call(__MODULE__, initial, iri, graph, opts)

          bad ->
            {:error, "bad result of #{__MODULE__}.__new__/1: #{inspect(bad)}"}
        end
      end

      @spec to_rdf(struct, opts :: Keyword) :: {:ok, Graph.t()} | {:error, any}
      def to_rdf(%__MODULE__{} = mapping, opts \\ []) do
        ToRDF.call(mapping, opts)
      end

      @spec validate(struct, opts :: Keyword) :: {:ok, struct} | {:error, ValidationError.t()}
      def validate(%__MODULE__{} = mapping, opts \\ []) do
        Validation.call(mapping, opts)
      end

      @spec validate!(struct, opts :: Keyword) :: struct
      def validate!(%__MODULE__{} = mapping, opts \\ []) do
        case validate(mapping, opts) do
          {:ok, _} -> mapping
          {:error, error} -> raise error
        end
      end

      @spec valid?(struct, opts :: Keyword) :: boolean
      def valid?(%__MODULE__{} = mapping, opts \\ []) do
        match?({:ok, _}, validate(mapping, opts))
      end
    end
  end
end
