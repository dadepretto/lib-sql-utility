create view [Utility].[Session]
as
select
    sysutcdatetime()                            as [timestamp],
    [S].[session_id]                            as [session_id],
    [T].[text]                                  as [sql_text],
    [S].[login_name]                            as [login_name],
    [R].[wait_time]                             as [wait_time],
    [R].[wait_type]                             as [wait_type],
    [S].[cpu_time]                              as [cpu_time],
    [S].[reads]                                 as [reads],
    [S].[writes]                                as [writes],
    [S].[memory_usage]                          as [memory_usage],
    [S].[status]                                as [status],
    [R].[open_transaction_count]                as [open_transaction_count],
    [S].[host_name]                             as [host_name],
    [S].[program_name]                          as [program_name],
    [S].[last_request_start_time]               as [last_request_start_time],
    [S].[login_time]                            as [login_time],
    [P].[query_plan]                            as [plan]
from [sys].[dm_exec_sessions] as [S]
    left join [sys].[dm_exec_connections] as [C]
        on [S].[session_id] = [C].[session_id]
    left join [sys].[dm_exec_requests] as [R]
        on [S].[session_id] = [R].[session_id]
    outer apply [sys].[dm_exec_sql_text]([C].[most_recent_sql_handle]) as [T]
    outer apply [sys].[dm_exec_query_plan]([R].[plan_handle]) as [P]
where [S].[database_id] = db_id()
    and [S].[session_id] <> @@spid
    and [S].[is_user_process] = 1;
go
