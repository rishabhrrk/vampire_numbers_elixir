defmodule Proj1.Core do
  @moduledoc """
  Contains core functions to check if a number is a vampire number and
  print its fangs.
  """

  @doc """
  Runs the check for the number

  ## Parameters

    - num: The number to check

  ## Returns

    - String representing the number and its fangs if num is a vampire number, else nil

  """
  def check(num) do
    # Check if the digits are even or not
    #
    # Addition check: check if the number is composite - found to be
    # redundant, but exists to meet the definition of Vampire Numbers
    # Add the condition `&& is_composite?(num)` below to include the condition
    if rem(length(Integer.digits(num)), 2) == 0 do

      # Find half the numbers length, min max numbers of half its length
      size_num = div(length(Integer.digits(num)), 2)
      max_possible_gactor = get_max_possible_divisor(size_num, 10) - 1
      min_possible_factor = div(get_max_possible_divisor(size_num, 10), 10)

      factors = find_facts(num, max_possible_gactor, min_possible_factor, [])

      # Check if factors' digits are present in the number or not
      get_result = fn n -> check_digits(n, num) end
      fin = Enum.map(factors, fn j -> get_result.(j) end)
      result = Enum.filter(fin, & !is_nil(&1))

      if length(result) > 0 do
        fangs_str = result |> List.flatten |> Enum.join(" ")
        "#{num} #{fangs_str}"
      end
    end
  end

  # @doc """
  # Checks if a number is composite

  # ## Parameters

  #   - num: The number to check

  # ## Returns

  #   - boolean: true if num is composite, else false
  # """
  # def is_composite?(num) do
  #   stop = div(num,2)
  #   2..stop |> Enum.any?(fn i -> rem(num, i) == 0 end)
  # end

  @doc """
  Returns the maximum possible divisor with `digit` number of digits

  ## Parameters

    - digit: The number of digits
    - var: helper variable for computation
  """
  def get_max_possible_divisor(digit, var) when digit > 1, do: get_max_possible_divisor(digit - 1, var * 10)
  def get_max_possible_divisor(_digit, var), do: var

  @doc """
  Returns the factors of the number `num` recursively

  ## Parameters

    - num: The number to find the factors of
    - max_factor: The current divisor being checked
    - min_factor: The lower limit of divisors
    - list: List of factors previously computed
  """
  def find_facts(num, max_factor, min_factor, list) when max_factor > min_factor do

    # Is the number divisible by max_factor
    is_num_divisible = rem(num, max_factor) == 0

    # Check if the factor is repeated (it exists in list)
    is_factor_repeated = Enum.any?(list, fn(n) -> max_factor in n end) == false

    # Check if both factors have trailing zeroes
    is_both_factors_have_trailing_zeros = rem(max_factor, 10) + rem(div(num, max_factor), 10) != 0

    # Check if the factor is a whole number or not
    is_factor_whole = div(num, max_factor) <= max_factor

    if is_num_divisible && is_factor_repeated && is_both_factors_have_trailing_zeros && is_factor_whole do
      find_facts(num, max_factor - 1, min_factor, list ++ [[max_factor, div(num, max_factor)]])
    else
      find_facts(num, max_factor - 1, min_factor, list)
    end
  end

  def find_facts(_num, _max_factor, _min_factor, list), do: list

  @doc """
  Returns a list of factors that form a permutation of the number

  1. Takes in a list comprising of two factors.
  2. Merges both the numbers into a single list and sorts the concatenated list
  3. It matches the concatenated list with the number which is also in form of a sorted list

  ## Parameters

    - list: a list of two factors which is a sublist of all the factors for a particular number
    - num: the number to which list belongs
  """
  def check_digits(list, num) do
    digits_list = flatten_list(list, [])
    if Enum.sort(digits_list) == Enum.sort(Integer.digits(num)), do: list
  end

  @doc """
  Returns a flattened list of the digits in the Integers present in the list `list`

  ## Parameters

   - A list of integers
   - list: Helper list for computation

  ## Examples

    iex> flatten_list([123, 123], [])
    [1, 2, 3, 1, 2, 3]
  """
  def flatten_list([], list), do: list
  def flatten_list([head | tail], list), do: flatten_list(tail, list ++ Integer.digits(head))

end


defmodule Proj1.Server do
  use GenServer

  def init(init_arg) do
    {:ok, init_arg}
  end

  def start_link(list) do
    {:ok, pid} = GenServer.start_link(__MODULE__, nil)
    GenServer.cast(pid, {:compute, list})
    {:ok, pid}
  end

  def handle_cast({:compute, list}, _state) do
    state =
      list
      |> Enum.map(fn n -> Proj1.Core.check(n) end)
      |> Enum.filter(fn n -> n != nil end)
    
    {:noreply, state}
  end

  def handle_call(:get_result, _from, state) do
    {:reply, state, nil}
  end
end


defmodule Proj1.CLI do
  @moduledoc """
  Entry point into the code. Run main() to start the project
  """

  # Number of numbers in the range handled by each worker
  @worker_size 100

  @doc """
  Runs the script

  ## Parameters

    - args: The arguments comprising of two integer strings in a list
  """
  def main(args) do

    # :observer.start()

    if length(args) != 2 do
      IO.puts "Usage: mix run proj1.exs n1 n2"
      exit(:shutdown)
    end

    n1 = Enum.at(args, 0) |> String.to_integer
    n2 = Enum.at(args, 1) |> String.to_integer

    children = n1..n2
      |> Enum.chunk_every(@worker_size)
      |> Enum.map(fn x -> Supervisor.child_spec({Proj1.Server, x}, id: Enum.at(x, 0)) end)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Proj1.Supervisor]
    Supervisor.start_link(children, opts)

    # IO.inspect Supervisor.which_children(Proj1.Supervisor)

    result = 
      Supervisor.which_children(Proj1.Supervisor)
      |> Enum.map(fn {_, pid, :worker, _} -> pid end)
      |> Enum.map(fn pid -> GenServer.call(pid, :get_result) end)
      |> Enum.filter(fn i -> i != [] end)
      |> Enum.sort

    Enum.map(result, fn line ->
      IO.puts Enum.join(line, "\n")
    end)
  end
end

# Start the script
Proj1.CLI.main(System.argv())
