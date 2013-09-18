defmodule OtpDsl.Genfsm do

  @moduledoc OtpDsl.Util.LazyDoc.for("## OtpDsl.Gemfsm")

  def generate_event({name, _line_no, nil}) do
    quote do
      def unquote(name)() do
        :gen_fsm.send_event(my_name, unquote(name))
      end
    end
  end

  def generate_event({name, _line_no, params}) do
    quote do
      def unquote(name)(unquote_splicing(params)) do
        :gen_fsm.send_event(my_name, {unquote(name), unquote_splicing(params)})
      end
    end
  end

  defmacro events([ do: {:__block__, [], event_list}]) do
    events = Enum.map event_list, generate_event(&1)
    quote do
      unquote_splicing(events)
    end
  end

  defmacro in_state(state, [do: { :->, _line_no, when_list}]) do
    states = Enum.map when_list, generate_state(state, &1)
    quote do
      unquote_splicing(states)
    end
  end

  def generate_state(state, {match, _line, action}) when is_list(match) do
    {params, context_pattern, when_clause} =
      case match do
        [ {:{}, _, params } ] -> {params, nil, nil}

        [ {:when, _, [ {:{}, _, params },
                       cpattern,
                       wclause ]
                       } ] ->
          {params, cpattern, wclause }
          [ {:when, _, [ {k, v},
                         wclause ] } ] ->
          {[k, v], nil, wclause}
      [ {k, v} ]                -> {[k, v], nil, nil}
    end

    params = case length(params) do
      1 -> quote do unquote(hd(params)) end
      _ -> quote do { unquote_splicing(params)} end
    end

    case when_clause do
      nil ->  
        quote hygiene: [vars: false ] do
          def unquote(state)(unquote(params), context) do
            unquote(action)
          end
        end
      _ ->
        case context_pattern do
          nil ->
            quote hygiene: [vars: false ] do
              def unquote(state)(unquote(params), context)
              when unquote(when_clause) do
                unquote(action)
              end
            end
          _ ->  
            quote hygiene: [vars: false ] do
              def unquote(state)(unquote(params), context=unquote(context_pattern))
              when unquote(when_clause) do
                unquote(action)
              end
            end
        end
    end
    
  end

  def next_state(new_state, context) do
    { :next_state, new_state, context }
  end

  def next_state(new_state, context, timeout) do
#    trace("#{new_state} #{timeout}mS #{inspect context}")
    { :next_state, new_state, context, timeout }
  end

  defmacro __using__(options) do
    register      = Keyword.get(options, :register, {:local, :fsm})
    initial_state = Keyword.get(options, :initial_state, :start)
    init_params   = Keyword.get(options, :init_params, [])
    tracing       = Keyword.get(options, :trace_transitions, nil)
    {_, my_name}  = register

    me = __MODULE__

    trace_func = quote do
      def trace(msg) do
        IO.puts "HELLO: #{inspect unquote(tracing)} #{msg}"
      end
    end

    quote do
      use GenFSM.Behaviour

      require unquote(me)
      import  unquote(me)

      def init(_) do
        {:ok, unquote(initial_state), unquote(init_params) }
      end

      def start_link() do
        :gen_fsm.start_link(unquote(register), __MODULE__, [], [])
      end

      def my_name, do: unquote(my_name)

      unquote(trace_func)
    end

  end

end
