# test-status

View the status of your projects test suite in the status bar of Atom.

**Please note:** I am no longer using Atom, this means I won't be actively
maintaining this project. I will still accept pull requests for bug fixes and
such.

## Installation

  * Install `test-status` in the **Packages** section in the preferences

## Configuration

When you first use `test-status` if you don't have a `test-status.cson` in your
Atom configuration directory it will create a default one for you.

The configuration contains the filename to command maps. These are the files it
will look for in your project root to determine which command to use to run your
test suite.

## Usage

The following commands are available for you to remap and/or run via the command
palette.

  * `test-status:toggle-output` toggles the test results output panel
  * `test-status:run-tests` runs the configured test command
