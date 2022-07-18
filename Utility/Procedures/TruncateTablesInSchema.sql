create procedure [Utility].[TruncateTablesInSchema]
(
    @SchemaName sysname,
    @ExcludedObjects nvarchar(max) = null,
    @IsDebug bit = 0
)
as
declare
    @excludedObjectList [Utility].[IntegerList],
    @objects nvarchar(max)
begin
    set xact_abort, nocount on;
    set transaction isolation level serializable;

    begin transaction;
    begin try
        insert into @excludedObjectList ([value])
        select [object_id]
        from [Utility].[ParseObjectsFull](@ExcludedObjects, @SchemaName);

        set @objects =
        (
            select [object_id]
            from [sys].[objects] as [O]
            where [O].[schema_id] = schema_id(@SchemaName)
                and [O].[object_id] not in
                (
                    select [value]
                    from @excludedObjectList
                )
            for json path
        );

        execute [Utility].[TruncateTables]
            @Objects = @objects,
            @IsDebug = @IsDebug;

        commit transaction;
    end try
    begin catch
        if @@trancount > 0
        begin
            rollback transaction;
        end;
        
        throw;
    end catch
end;
go