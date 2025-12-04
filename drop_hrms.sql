USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'HRMS')
BEGIN
    ALTER DATABASE HRMS SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE HRMS;
    PRINT 'HRMS database dropped successfully.';
END
ELSE
BEGIN
    PRINT 'HRMS database does not exist.';
END
GO
