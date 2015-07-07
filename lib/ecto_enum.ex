defmodule Ecto.Enum do

  import Ecto.Changeset

  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :ecto_enums, accumulate: true)
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    mod    = env.module
    fields = Module.get_attribute(mod, :changeset_fields)
    enums  = Module.get_attribute(mod, :ecto_enums)

    if enums do
      for {name, enum_list} <- enums do
        if fields[name] != :integer do
          raise ArgumentError, "only an `:integer` field can be an enum"
        end

        enum_map =
          for {field, number} <- enum_list, into: %{} do
            {number, field}
          end

        quote do
          name       = unquote(name)
          enum_field = :"enum_#{name}"
          enum_list  = unquote(enum_list)
          enum_map   = unquote(Macro.escape(enum_map))
          mod        = unquote(mod)

          before_insert Ecto.Enum, :set_enum, [name, enum_field, enum_map, enum_list]
          before_update Ecto.Enum, :set_enum, [name, enum_field, enum_map, enum_list]
          after_load    Ecto.Enum, :on_load, [name, enum_field, enum_map]
        end
      end
    end
  end

  defmacro enum(field, list) when is_list(list) do
    enum_field = :"enum_#{field}"

    helper_fields =
      for {field, _number} <- list do
        helper_name = :"#{field}?"

        quote do
          def unquote(helper_name)(model) do
            value = Map.get(model, unquote(enum_field))
            unquote(field) == value
          end
        end
      end

    quote do
      field      = unquote(field)
      enum_field = unquote(enum_field)
      list       = unquote(list)

      @ecto_enums {field, list}
      Ecto.Schema.__field__(__MODULE__, field, :integer, false, [])
      Ecto.Schema.__field__(__MODULE__, enum_field, :string, false, virtual: true)
      unquote(helper_fields)
      Module.eval_quoted __ENV__, [Ecto.Enum.__enums__(field, enum_field, list)]
    end
  end

  def on_load(model, name, enum_field, enum_map) do
    int           = Map.get(model, name)
    current_value = enum_map[int]
    model
    |> Map.put(enum_field, current_value)
    |> Map.put(current_value, true)
  end

  def set_enum(changeset, name, enum_field, enum_map, enum_list) do
    cond do
      int = get_change(changeset, name) ->
        value = enum_map[int]
        changeset
        |> put_change(enum_field, value)

      enum_field = get_field(changeset, enum_field) ->
        enum_int = enum_list[enum_field]
        changeset
        |> change([{name, enum_int}])

      true ->
        changeset
    end
  end

  def __enums__(name, enum_field, enum_list) do
    quote do
      def __enums__(unquote(name)) do
        unquote(enum_list)
      end

      def __enums__(unquote(enum_field)) do
        unquote(enum_list)
      end
    end
  end
end
