--1 ViewEmployeeInfo
/*
EXEC ViewEmployeeInfo @EmployeeID = 1;
*/
--2 AddEmployee
/*
SELECT employee_id, full_name, email, national_id FROM Employee;

EXEC AddEmployee
    @FullName = 'John Snow',
    @NationalID = '30001011234567',
    @DateOfBirth = '1995-01-01',
    @CountryOfBirth = 'Egypt',
    @Phone = '01099999999',
    @Email = 'john.snow@example.com',
    @Address = 'New Cairo',
    @EmergencyContactName = 'Mary Snow',
    @EmergencyContactPhone = '01234567890',
    @Relationship = 'Mother',
    @Biography = 'New hire bio',
    @EmploymentProgress = 'Onboarding',
    @AccountStatus = 'Active',
    @EmploymentStatus = 'Full-time',
    @HireDate = '2025-01-01',
    @IsActive = 1,
    @ProfileCompletion = 80,
    @DepartmentID = 1,
    @PositionID = 1,
    @ManagerID = NULL,
    @ContractID = 1,
    @TaxFormID = 1,
    @SalaryTypeID = 1,
    @PayGrade = 1;
*/
--3 UpdateEmployeeInfo
/*
SELECT employee_id, full_name, email, phone, address
FROM Employee
WHERE employee_id = 2;
EXEC UpdateEmployeeInfo
    @EmployeeID = 2,
    @Email = 'sara.new@example.com',
    @Phone = '01555555555',
    @Address = 'New Cairo';
SELECT employee_id, full_name, email, phone, address
FROM Employee
WHERE employee_id = 2;
*/
--4 AssignRole
/*
SELECT employee_id, full_name, is_active FROM Employee;
SELECT role_id, role_name FROM Role;
SELECT role_id, role_name FROM Role;
EXEC AssignRole 
     @EmployeeID = 2,
     @RoleID = 2;
SELECT employee_id, role_id, assigned_date
FROM Employee_Role
WHERE employee_id = 2;
*/
--5 GetDepartmentEmployeeStats
/*
SELECT employee_id, full_name, department_id FROM Employee;
EXEC GetDepartmentEmployeeStats;
*/
--6 ReassignManager
/*
SELECT employee_id, full_name, manager_id FROM Employee;
SELECT * FROM EmployeeHierarchy;

EXEC ReassignManager
    @EmployeeID = 2,
    @NewManagerID = 3;

SELECT employee_id, full_name, manager_id
FROM Employee
WHERE employee_id = 2;
SELECT * FROM EmployeeHierarchy WHERE employee_id = 2;
*/
--7 ReassignHierarchy
/*
SELECT employee_id, full_name, department_id, manager_id 
FROM Employee WHERE employee_id = 2;
SELECT * FROM EmployeeHierarchy WHERE employee_id = 2;
EXEC ReassignHierarchy
    @EmployeeID = 2,
    @NewDepartmentID = 3,
    @NewManagerID = 3;
SELECT employee_id, full_name, department_id, manager_id
FROM Employee WHERE employee_id = 2;
SELECT * FROM EmployeeHierarchy WHERE employee_id = 2;
*/
--8 NotifyStructureChange
/*
SELECT COUNT(*) FROM Notification;
SELECT * FROM Employee_Notification;
EXEC NotifyStructureChange
    @AffectedEmployees = '1,2,3',
    @Message = 'Organizational structure updated.';
SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;
SELECT * FROM Employee_Notification WHERE notification_id = 1;
*/
--9 ViewOrgHierarchy
/*
SELECT employee_id, full_name, department_id, position_id, manager_id
FROM Employee;
SELECT * FROM EmployeeHierarchy;
EXEC ViewOrgHierarchy;
*/