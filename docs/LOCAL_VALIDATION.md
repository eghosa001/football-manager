# Local Windows validation

Use Godot 4.7.2 and PowerShell from the repository root:

```powershell
./tools/test-local.ps1 -Godot 'C:/path/to/Godot_v4.7.2-stable_win64_console.exe'
```

The runner imports the project, runs each suite in a separate user-data directory, checks both exit codes and error logs, and requires a PASS marker. Each suite has a ten-minute timeout. Increase `-TimeoutSeconds` for the season soak on slower machines. Generated logs and test saves live in `.local-tests/` and are ignored by Git. Real careers are not used by this runner.

For the production career checks only:

```powershell
./tools/test-local.ps1 -Godot 'C:/path/to/Godot_v4.7.2-stable_win64_console.exe' -Suites registration_safety_test,save_safety_test,career_ui_test,rc2_integration_test
```

Running individual Godot test scripts directly uses the normal `user://` directory. Some existing scripts create and delete numbered saves; use the isolated runner instead when you have real careers on this computer.

The default runner does not install SQLite or export templates, build release packages, or run the optional 100,000-match gate. Those remain separate release checks. UI tests exercise scene construction and callbacks headlessly; they do not replace visual and interactive playtesting.
