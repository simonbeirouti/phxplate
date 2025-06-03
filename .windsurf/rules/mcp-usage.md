---
trigger: always_on
---

We have the tidewave mcp and we can use this to automatically interact with the phoenix applicaiton. You have the following tools to use:

get_logs
Returns all log output, excluding logs that were caused by other tool calls. Use this tool to check for request logs or potentially logged errors.

get_source_location
Returns the source location for the given reference. This works for modules in the current project, as well as dependencies, but not for modules included in Elixir itself. This tool only works if you know the `Module`, `Module.function`, or `Module.function/arity` that is being targeted. If that is the case, prefer this tool over grepping the file system.

project_eval
Evaluates Elixir code in the context of the project. The current Elixir version is: 1.18.3 Use this tool every time you need to evaluate Elixir code, including to test the behaviour of a function or to debug something. The tool also returns anything written to standard output. DO NOT use shell tools to evaluate Elixir code. It also includes IEx helpers in the evaluation context. Thus, to get documentation for a module or function, use this tool and execute the `h` helper, for example: h Enum.map/2

execute_sql_query
Executes the given SQL query against the given default or specified Ecto repository. Returns the result as an Elixir data structure. Note that the output is limited to 50 rows at a time. If you need to see more, perform additional calls using LIMIT and OFFSET in the query. If you know that only specific columns are relevant, only include those in the SELECT clause. You can use this tool to select user data, manipulating entries, and introspect the application data domain. Always ensure to use the correct SQL commands for the database you are using. The description of the repo parameter includes a list of available repositories and their adapters.

get_ecto_schemas
Lists all Ecto schema modules and their file path in the current project. Use this tool to get an overview of available schemas if the project uses Ecto. You should prefer this tool over grepping the file system when you need to find a specific schema.

get_process_info
Returns detailed information about a process. Either a pid or a name must be provided. Use this tool to find out more about a process, for example to debug a problem with a specific LiveView or named GenServer.

trace_process
Traces messages sent to and from a process until the specified message count is reached. This is a very specific tool, use it only if the user needs to debug something happening in a process like a GenServer or a LiveView and is not sure what's going on. When you try to use the tool, inform the user that you are going to trace the process, and ask them to perform the action they're having problems with after starting the tool call. Start with a low message count, for example 10 and only increase it if necessary. This tool blocks the execution until the specified number of messages has been traced or the timeout is reached.

list_liveview_pages
Returns a list of currently connected LiveViews. Use this tool if the project is using Phoenix LiveView and a user talks about something that is happening in the current page or the current LiveView.

package_docs_search
Searches Hex documentation for the project's dependencies or a list of packages. If you're trying to get documentation for a specific module or function, first try the `project_eval` tool with the `h` helper.

package_search
Searches for packages on Hex. Use this tool if you need to find new packages to add to the project. Before using this tool, get an overview of the existing dependencies by using the `project_eval` tool and executing `Mix.Project.deps_apps()`. By default, the packages are sorted by popularity (number of downloads).

Make sure we're using these together or separately to optimise the workflow.