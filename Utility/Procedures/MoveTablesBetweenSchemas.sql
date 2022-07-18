create procedure [Utility].[MoveTablesBetweenSchemas]
(
    @SourceSchemaName sysname,
    @TargetSchemaName sysname,
    @IsDebug bit = 0
)
as
declare
    @tables cursor,
    @tableName sysname,
    @stmt nvarchar(max);
begin
    set xact_abort, nocount on;
    set transaction isolation level serializable;

    begin transaction;
    begin try
        set @tables = cursor forward_only static read_only for
        (
            select [name]
            from [sys].[tables]
            where [schema_id] = schema_id(@SourceSchemaName)
        );

        open @tables;

        fetch next from @tables into @tableName;

        while @@fetch_status = 0
        begin
            set @stmt = concat(
                N'alter schema ', quotename(@TargetSchemaName),
                N' transfer object::', 
                quotename(@SourceSchemaName), N'.', quotename(@tableName)
            );

            if isnull(@IsDebug, 0) = 1
            begin
                raiserror(@stmt, 10, 1) with nowait;
            end;

            execute [sys].[sp_executesql]
                @stmt = @stmt;

            fetch next from @tables into @tableName;
        end;

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