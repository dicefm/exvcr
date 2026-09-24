ExUnit.start()

# The suite runs on hackney < 3.0; keep the one-time upgrade warning out of test output.
:persistent_term.put({ExVCR.Adapter.Hackney, :old_hackney_warned}, true)
Application.ensure_all_started(:http_server)
Application.ensure_all_started(:telemetry)
Finch.start_link(name: ExVCRFinch)
