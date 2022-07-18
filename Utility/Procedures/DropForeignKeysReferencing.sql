create procedure [Utility].[DropForeignKeysReferencing]
(
    @Objects nvarchar(max),
    @StatementsToRecreate nvarchar(max) = null output,
    @OutputStatementsToRecreateAsTable bit = 0,
    @IsDebug bit = 0
)
as
declare
    @objectList [Utility].[IntegerList],
    @constraints cursor,
    @constraintName nvarchar(258),
    @schemaName nvarchar(258),
    @objectName nvarchar(258),
    @stmt nvarchar(max);
begin
    set xact_abort, nocount on;
    set transaction isolation level serializable;

    begin transaction;
    begin try
        insert into @objectList ([value])
        select [object_id]
        from [Utility].[ParseObjectsSimple](@Objects);

        drop table if exists [#StatementsToRecreate];

        create table [#StatementsToRecreate]
        (
            [Statement] nvarchar(max) primary key
        );

        insert into [#StatementsToRecreate]
        select concat(
            N'alter table ', [QPS].[name], N'.', [QP].[name], N' ',
            N'add constraint ', [QFK].[name], N' foreign key ',
            N'(', [QPC].[columns], N') ',
            N'references ', [QRS].[name], N'.',[QR].[name],
            N'(', [QRC].[columns], N') ',
            N'on update ', case [FK].[update_referential_action]
                when 0 then N'no action'
                when 1 then N'cascade'
                when 2 then N'set null'
                when 3 then N'set default'
            end, N' ',
            N'on delete ', case [FK].[delete_referential_action]
                when 0 then N'no action'
                when 1 then N'cascade'
                when 2 then N'set null'
                when 3 then N'set default'
            end,
            case [FK].[is_not_for_replication]
                when 0 then N''
                when 1 then N' not for replication'
            end, N';'
        )
        from [sys].[foreign_keys] as [FK]
            cross apply (select quotename([FK].[name])) as [QFK]([name])
            inner join [sys].[objects] as [P]
                on [FK].[parent_object_id] = [P].[object_id]
            cross apply (select quotename([P].[name])) as [QP]([name])
            inner join [sys].[schemas] as [PS]
                on [P].[schema_id] = [PS].[schema_id]
            cross apply (select quotename([PS].[name])) as [QPS]([name])
            cross apply
            (
                select string_agg(quotename([C].[name]), N',')
                    within group (order by [FKC].[constraint_column_id])
                from [sys].[foreign_key_columns] as [FKC]
                    inner join [sys].[columns] as [C]
                        on [FKC].[parent_object_id] = [C].[object_id]
                            and [FKC].[parent_column_id] = [C].[column_id]
                where [FKC].[constraint_object_id] = [FK].[object_id]
            ) as [QPC]([columns])
            inner join [sys].[tables] as [R]
                on [FK].[referenced_object_id] = [R].[object_id]
            cross apply (select quotename([R].[name])) as [QR]([name])
            inner join [sys].[schemas] as [RS]
                on [R].[schema_id] = [RS].[schema_id]
            cross apply (select quotename([RS].[name])) as [QRS]([name])
            cross apply
            (
                select string_agg(quotename([C].[name]), N',')
                    within group (order by [FKC].[constraint_column_id])
                from [sys].[foreign_key_columns] as [FKC]
                    inner join [sys].[columns] as [C]
                        on [FKC].[referenced_object_id] = [C].[object_id]
                            and [FKC].[referenced_column_id] = [C].[column_id]
                where [FKC].[constraint_object_id] = [FK].[object_id]
            ) as [QRC]([columns])
        where [FK].[referenced_object_id] in
        (
            select [value]
            from @objectList
        );

        set @StatementsToRecreate = 
        (
            select string_agg([Statement], N' ')
            from [#StatementsToRecreate]
        );

        if isnull(@OutputStatementsToRecreateAsTable, 0) = 1
        begin
            select [Statement]
            from [#StatementsToRecreate];
        end;

        set @constraints = cursor forward_only static read_only for
        (
            select
                [QPS].[name]    as [schema_name],
                [QP].[name]     as [object_name],
                [QFK].[name]    as [constraint_name]
            from [sys].[foreign_keys] as [FK]
                cross apply (select quotename([FK].[name])) as [QFK]([name])
                inner join [sys].[objects] as [P]
                    on [FK].[parent_object_id] = [P].[object_id]
                cross apply (select quotename([P].[name])) as [QP]([name])
                inner join [sys].[schemas] as [PS]
                    on [P].[schema_id] = [PS].[schema_id]
                cross apply (select quotename([PS].[name])) as [QPS]([name])
            where [FK].[referenced_object_id] in
            (
                select [value]
                from @objectList
            )
        );

        open @constraints;

        fetch next from @constraints
        into @schemaName, @objectName, @constraintName;

        while @@fetch_status = 0
        begin
            set @stmt = concat(
                N'alter table ', @schemaName, N'.', @objectName, N' ',
                N'drop constraint', @constraintName, N';'
            );

            if isnull(@IsDebug, 0) = 1
            begin
                raiserror(@stmt, 10, 1) with nowait;
            end;

            execute [sys].[sp_executesql]
                @stmt = @stmt;

            fetch next from @constraints
            into @schemaName, @objectName, @constraintName;
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
