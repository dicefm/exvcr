defmodule ExVCR.Adapter.HackneyBodyTest do
  # Not async: the upgrade warning is tracked in a VM-wide :persistent_term flag.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias ExVCR.Adapter.Hackney
  alias ExVCR.Adapter.Hackney.Store

  @warned_key {Hackney, :old_hackney_warned}
  @response %ExVCR.Response{type: "ok", status_code: 200, headers: [], body: "recorded body"}

  # The warning is marked as already shown; the warning tests reset it themselves.
  setup do
    Store.start()
    warned = :persistent_term.get(@warned_key, false)
    :persistent_term.put(@warned_key, true)
    on_exit(fn -> :persistent_term.put(@warned_key, warned) end)
  end

  describe "hackney >= 3.0" do
    for version <- ["3.0.0", "4.7.4"] do
      test "returns the recorded body inline on #{version}, with or without :with_body" do
        assert Hackney.hook_response_from_cache(request([]), @response, unquote(version)) == @response
        assert Hackney.hook_response_from_cache(request([:with_body]), @response, unquote(version)) == @response
      end

      test "does not log the upgrade warning on #{version}" do
        :persistent_term.erase(@warned_key)

        assert capture_log(fn -> Hackney.hook_response_from_cache(request([]), @response, unquote(version)) end) ==
                 ""
      end
    end
  end

  describe "hackney < 3.0" do
    test "returns the recorded body inline when :with_body is passed" do
      assert Hackney.hook_response_from_cache(request([:with_body]), @response, "1.23.0") == @response
      assert Hackney.hook_response_from_cache(request(with_body: true), @response, "1.23.0") == @response
    end

    test "returns a reference that holds the recorded body when :with_body is not passed" do
      %ExVCR.Response{body: ref} = Hackney.hook_response_from_cache(request([]), @response, "2.0.0")

      assert is_reference(ref)
      assert Store.get(ref |> inspect() |> String.to_atom()) == "recorded body"
    end

    test "logs the upgrade warning once" do
      :persistent_term.erase(@warned_key)

      log =
        capture_log(fn ->
          Hackney.hook_response_from_cache(request([]), @response, "1.23.0")
          Hackney.hook_response_from_cache(request([]), @response, "1.23.0")
        end)

      assert log =~ "ExVCR: hackney 1.23.0 returns response bodies by reference"
      assert length(String.split(log, "please upgrade hackney")) == 2
    end
  end

  defp request(opts), do: [:get, "http://example.com", [], "", opts]
end
