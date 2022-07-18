/*
author: Davide De Pretto
summary:    >
    Parse a JSON string containing a list of objects, represented either as
    - An object id                                (e.g. 101575)
    - An object name (unqualified, unquoted)      (e.g. "t1")
    - An object name (qualified, unquoted)        (e.g. "dbo.t1")
    - An object name (qualified, object quoted)   (e.g. "dbo.[t1]")
    - An object name (qualified, schema quoted)   (e.g. "[dbo].t1")
    - An object name (qualified, fully quoted)    (e.g. "[dbo].[t1]")
    - An object id inside a property "object_id"  (e.g. {"object_id": 101575})
parameters:
    - Objects: A JSON string representing a list of objects
    - DefaultSchema: A schema to use when no schema information is available
returns: A table containing one integer column "object_id"
*/
create function [Utility].[ParseObjectsFull]
(
    @Objects nvarchar(max),
    @DefaultSchema sysname
)
returns table
as
return
    select coalesce([P0].[object_id], [P1].[object_id]) as [object_id]
from openjson(@Objects) as [IO]
    left join [sys].[objects] as [P0]
    on [IO].[type] = 2 /* number */
        and [IO].[value] = [P0].[object_id]
    left join [sys].[objects] as [P1]
    on [IO].[type] = 1 /* string */
        and [P1].[name] = parsename([IO].[value], 1)
        and isnull(parsename([IO].[value], 2), @DefaultSchema) =
                    object_schema_name([P1].[object_id])
    left join [sys].[objects] as [P2]
    on [IO].[type] = 5 /* object */
        and json_value([IO].[Value], '%.object_id') = [P2].[object_id]
where coalesce([P0].[object_id], [P1].[object_id]) is not null;
go
