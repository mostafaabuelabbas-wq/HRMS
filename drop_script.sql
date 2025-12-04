USE HRMS;
GO

-- Disable all constraints
EXEC sp_msforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT ALL";

-- Drop all foreign keys
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += 'ALTER TABLE [' + OBJECT_NAME(parent_object_id) + '] DROP CONSTRAINT [' + name + '];'
FROM sys.foreign_keys;
EXEC sp_executesql @sql;

-- Drop all tables
EXEC sp_msforeachtable "DROP TABLE ?";

PRINT 'All tables dropped successfully from HRMS.';
GO
