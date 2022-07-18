create procedure [Utility].[SwapTablesBetweenSchemas]
(
    @FirstSchemaName sysname,
    @SecondSchemaName sysname,
    @IsDebug bit = 0
)
as
declare
    @temporarySchemaName sysname,
    @stmt nvarchar(max);
begin
    set xact_abort, nocount on;
    set transaction isolation level serializable;

    begin transaction;
    begin try
        set @temporarySchemaName = concat(
            object_name(@@procid),
            N'::', convert(nvarchar(27), sysutcdatetime(), 127),
            N'::', convert(nvarchar(36), newid())
        );

        set @stmt = concat(
            N'create schema ', quotename(@temporarySchemaName), N';'
        );

        if isnull(@IsDebug, 0) = 1
        begin
            raiserror(@stmt, 10, 1) with nowait;
        end;

        execute [sys].[sp_executesql]
            @stmt = @stmt;

        execute [Utility].[MoveTablesBetweenSchemas]
            @SourceSchemaName = @FirstSchemaName,
            @TargetSchemaName = @temporarySchemaName,
            @IsDebug = @IsDebug;

        execute [Utility].[MoveTablesBetweenSchemas]
            @SourceSchemaName = @SecondSchemaName,
            @TargetSchemaName = @FirstSchemaName,
            @IsDebug = @IsDebug;

        execute [Utility].[MoveTablesBetweenSchemas]
            @SourceSchemaName = @temporarySchemaName,
            @TargetSchemaName = @SecondSchemaName,
            @IsDebug = @IsDebug;

        set @stmt = concat(
            N'drop schema ', quotename(@temporarySchemaName), N';'
        );

        if isnull(@IsDebug, 0) = 1
        begin
            raiserror(@stmt, 10, 1) with nowait;
        end;

        execute [sys].[sp_executesql]
            @stmt = @stmt;

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