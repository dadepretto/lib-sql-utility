create procedure [Utility].[DropTables]
(
    @Objects nvarchar(max),
    @IsDebug bit = 0
)
as
declare
    @objectList [Utility].[IntegerList],
    @tables cursor,
    @schemaName nvarchar(258),
    @tableName nvarchar(258),
    @stmt nvarchar(max);
begin
    set xact_abort, nocount on;
    set transaction isolation level serializable;

    begin transaction;
    begin try
        insert into @objectList ([value])
        select [object_id]
        from [Utility].[ParseObjectsSimple](@Objects);

        execute [Utility].[DropForeignKeysReferencing]
            @Objects = @Objects,
            @IsDebug = @IsDebug;

        set @tables = cursor forward_only static read_only for
        (
            select
                [QTS].[name]    as [schema_name],
                [QT].[name]     as [object_name]
            from [sys].[tables] as [T]
                cross apply (select quotename([T].[name])) as [QT]([name])
                inner join [sys].[schemas] as [TS]
                    on [T].[schema_id] = [TS].[schema_id]
                cross apply (select quotename([TS].[name])) as [QTS]([name])
            where [T].[object_id] in (select [value] from @objectList)
        );

        open @tables;

        fetch next from @tables into @schemaName, @tableName;

        while @@fetch_status = 0
        begin
            set @stmt = concat(
                N'drop table ', @schemaName, N'.', @tableName, N' '
            );

            if isnull(@IsDebug, 0) = 1
            begin
                raiserror(@stmt, 10, 1) with nowait;
            end;

            execute [sys].[sp_executesql]
                @stmt = @stmt;

            fetch next from @tables into @schemaName, @tableName;
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
