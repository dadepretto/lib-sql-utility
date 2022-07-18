create view [Utility].[ObjectStorageStat]
as
select
    [SC].[schema_id]                            as [schema_id],
    [SC].[name]                                 as [schema_name],
    [TB].[object_id]                            as [table_id],
    [TB].[name]                                 as [table_name],
    [IX].[index_id]                             as [index_id],
    [IX].[name]                                 as [index_name],
    [IX].[type_desc]                            as [index_type],
    [PT].[partition_id]                         as [partition_id],
    [PT].[partition_number]                     as [partition_number],
    [PT].[rows]                                 as [rowcount],
    [DCD].[data_compression_desc]               as [data_compression],
    cast([FPP].[free_percent] as decimal(5, 2)) as [free_percent],
    cast([GB].[total_space] as decimal(12, 4))  as [total_space_GB],
    cast([GB].[used_space] as decimal(12, 4))   as [used_space_GB],
    cast([GB].[free_space] as decimal(12, 4))   as [free_space_GB],
    [IS].[user_seeks]                           as [seeks_count],
    [IS].[user_scans]                           as [scans_count],
    [IS].[user_lookups]                         as [lookups_count],
    [IS].[user_updates]                         as [updates_count],
    [IS].[last_user_seek]                       as [last_seek],
    [IS].[last_user_scan]                       as [last_scan],
    [IS].[last_user_lookup]                     as [last_lookup],
    [IS].[last_user_update]                     as [last_update]
from [sys].[schemas] as [SC]
    inner join [sys].[tables] as [TB]
        on [SC].[schema_id] = [TB].[schema_id]
    inner join [sys].[indexes] as [IX]
        on [TB].[object_id] = [IX].[object_id]
    inner join [sys].[partitions] as [PT]
        on [TB].[object_id] = [PT].[object_id]
            and [IX].[index_id] = [PT].[index_id]
    left join [sys].[dm_db_index_usage_stats] as [IS]
        on [TB].[object_id] = [IS].[object_id]
            and [IX].[index_id] = [IS].[index_id]
    left join [sys].[dm_db_partition_stats] as [PS]
        on [TB].[object_id] = [PS].[object_id]
            and [IX].[index_id] = [PS].[index_id]
            and [PT].[partition_id] = [PS].[partition_id]
    outer apply
    (
        select [PS].[reserved_page_count] - [PS].[used_page_count]
    ) as [FP]([free_pages])
    outer apply
    (
        select [FP].[free_pages] * 100.0 / nullif([PS].[reserved_page_count], 0)
    ) as [FPP]([free_percent])
    outer apply (
        select
            [PS].[reserved_page_count] / 131072.0,
            [PS].[used_page_count] / 131072.0,
            [FP].[free_pages] / 131072.0
    ) as [GB]([total_space], [used_space], [free_space])
    outer apply
    (
        select case [PT].[data_compression_desc]
            when N'NONE' then N'-'
            else [data_compression_desc]
        end
    ) as [DCD]([data_compression_desc]);
go