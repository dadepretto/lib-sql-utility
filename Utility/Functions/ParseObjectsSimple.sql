create function [Utility].[ParseObjectsSimple]
(
    @Objects nvarchar(max)
)
returns table
as
return
    select [object_id]
    from [Utility].[ParseObjectsFull](@Objects, schema_name());
go
