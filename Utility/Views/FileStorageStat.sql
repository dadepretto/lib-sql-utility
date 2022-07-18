create view [Utility].[FileStorageStat]
as
select
    [DF].[type_desc]                            as [file_type],
    [DF].[name]                                 as [file_name],
    cast([GB].[total_space] as decimal(12, 4))  as [total_space_GB],
    cast([GB].[used_space] as decimal(12, 4))   as [used_space_GB],
    cast([GB].[free_space] as decimal(12, 4))   as [free_space_GB],
    cast([PT].[free_percent] as decimal(5, 2))  as [free_percent],
    case [DF].[max_size]
        when -1 then N'Unrestricted'
        when 0 then N'Disabled'
        else format(([DF].[max_size] / 131072.0), N'N2')
    end                                         as [max_space_GB]
from [sys].[database_files] as [DF]
    outer apply (
        select [DF].[size] - fileproperty([DF].[name], N'spaceused')
    ) as [FP]([free_pages])
    outer apply (
        select [FP].[free_pages] * 100.0 / nullif([DF].[size], 0)
    ) as [PT]([free_percent])
    outer apply (
        select
            [DF].[size] / 131072.0,
            fileproperty([DF].[name], N'spaceused') / 131072.0,
            [free_pages] / 131072.0
    ) as [GB]([total_space], [used_space], [free_space])