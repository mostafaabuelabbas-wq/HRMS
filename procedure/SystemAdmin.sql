--System admin
-- 1. ViewEmployeeInfo
GO
CREATE PROCEDURE ViewEmployeeInfo
    @EmployeeID INT
AS
BEGIN
    SELECT 
        e.*,
        d.department_name,
        p.position_title,
        c.type AS contract_type,
        c.start_date AS contract_start,
        c.end_date AS contract_end,
        st.type AS salary_type,
        pg.grade_name,
        pg.min_salary,
        pg.max_salary
    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    LEFT JOIN Contract c ON e.contract_id = c.contract_id
    LEFT JOIN SalaryType st ON e.salary_type_id = st.salary_type_id
    LEFT JOIN PayGrade pg ON e.pay_grade = pg.pay_grade_id
    WHERE e.employee_id = @EmployeeID;
END;
GO


CREATE PROCEDURE AddEmployee
    @FullName VARCHAR(100),
    @Email VARCHAR(100),
    @DepartmentID INT,
    @PositionID INT,
    @HireDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FirstName VARCHAR(50);
    DECLARE @LastName VARCHAR(50);

    -- Split @FullName into first and last name
    SET @FirstName = LEFT(@FullName, CHARINDEX(' ', @FullName + ' ') - 1);
    SET @LastName  = SUBSTRING(@FullName, CHARINDEX(' ', @FullName + ' ') + 1, LEN(@FullName));

    -- Insert without touching full_name (computed column)
    INSERT INTO Employee (
        first_name,
        last_name,
        email,
        department_id,
        position_id,
        hire_date,
        is_active
    )
    VALUES (
        @FirstName,
        @LastName,
        @Email,
        @DepartmentID,
        @PositionID,
        @HireDate,
        1
    );

    SELECT 
        SCOPE_IDENTITY() AS NewEmployeeID,
        'Employee added successfully.' AS ConfirmationMessage;
END;
GO


-- 3. UpdateEmployeeInfo
CREATE PROCEDURE UpdateEmployeeInfo
    @EmployeeID INT,
    @Email VARCHAR(100),
    @Phone VARCHAR(20),
    @Address VARCHAR(150)
AS
BEGIN
    UPDATE Employee
    SET email = @Email,
        phone = @Phone,
        address = @Address
    WHERE employee_id = @EmployeeID;

    SELECT 'Employee information updated successfully' AS ConfirmationMessage;
END;
GO
-- 4. AssignRole
CREATE PROCEDURE AssignRole
    @EmployeeID INT,
    @RoleID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if the employee already has this role
    IF EXISTS (
        SELECT 1 
        FROM Employee_Role
        WHERE employee_id = @EmployeeID
          AND role_id = @RoleID
    )
    BEGIN
        SELECT 'Role already assigned to this employee.' AS Message;
        RETURN;
    END

    -- Insert new role assignment
    INSERT INTO Employee_Role (employee_id, role_id, assigned_date)
    VALUES (@EmployeeID, @RoleID, GETDATE());

    SELECT 'Role assigned successfully.' AS Message;
END;
GO

-- 5. GetDepartmentEmployeeStats
CREATE PROCEDURE GetDepartmentEmployeeStats
AS
BEGIN
    SELECT 
        d.department_id,
        d.department_name,
        COUNT(e.employee_id) AS number_of_employees
    FROM Department d
    LEFT JOIN Employee e ON d.department_id = e.department_id
    GROUP BY d.department_id, d.department_name
    ORDER BY number_of_employees DESC;
END;
GO

-- 6. ReassignManager
CREATE PROCEDURE ReassignManager
    @EmployeeID INT,
    @NewManagerID INT
AS
BEGIN
    UPDATE Employee
    SET manager_id = @NewManagerID
    WHERE employee_id = @EmployeeID;

    IF EXISTS (SELECT 1 FROM EmployeeHierarchy WHERE employee_id = @EmployeeID)
    BEGIN
        UPDATE EmployeeHierarchy
        SET manager_id = @NewManagerID
        WHERE employee_id = @EmployeeID;
    END
    ELSE
    BEGIN
        INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
        VALUES (@EmployeeID, @NewManagerID, 1);
    END

    SELECT 'Manager reassigned successfully for employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO
-- 7. ReassignHierarchy
CREATE PROCEDURE ReassignHierarchy
    @EmployeeID INT,
    @NewDepartmentID INT,
    @NewManagerID INT
AS
BEGIN
    UPDATE Employee
    SET department_id = @NewDepartmentID,
        manager_id = @NewManagerID
    WHERE employee_id = @EmployeeID;

    IF EXISTS (SELECT 1 FROM EmployeeHierarchy WHERE employee_id = @EmployeeID)
    BEGIN
        UPDATE EmployeeHierarchy
        SET manager_id = @NewManagerID
        WHERE employee_id = @EmployeeID;
    END
    ELSE
    BEGIN
        INSERT INTO EmployeeHierarchy (employee_id, manager_id, hierarchy_level)
        VALUES (@EmployeeID, @NewManagerID, 1);
    END

    SELECT 'Employee hierarchy reassigned successfully for employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO

-- 8. NotifyStructureChange
CREATE PROCEDURE NotifyStructureChange
    @AffectedEmployees VARCHAR(500),
    @Message VARCHAR(200)
AS
BEGIN
    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES (@Message, 'High', 'Structure Change');

    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    SELECT 
        CAST(value AS INT),
        SCOPE_IDENTITY(),
        'Sent',
        GETDATE()
    FROM STRING_SPLIT(@AffectedEmployees, ',');

    SELECT 'Structure change notification sent to affected employees' AS ConfirmationMessage;
END;
GO

-- 9. ViewOrgHierarchy
CREATE PROCEDURE ViewOrgHierarchy
AS
BEGIN
    SELECT 
        e.employee_id,
        e.full_name AS employee_name,
        m.full_name AS manager_name,
        d.department_name,
        p.position_title,
        eh.hierarchy_level
    FROM Employee e
    LEFT JOIN Employee m ON e.manager_id = m.employee_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    LEFT JOIN EmployeeHierarchy eh ON e.employee_id = eh.employee_id
    ORDER BY eh.hierarchy_level, d.department_name, e.full_name;
END;
GO
-- 10. AssignShiftToEmployee
CREATE PROCEDURE AssignShiftToEmployee
    @EmployeeID INT,
    @ShiftID INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
    VALUES (@EmployeeID, @ShiftID, @StartDate, @EndDate, 'Active');

    SELECT 'Shift assigned successfully to employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO

-- 11. UpdateShiftStatus
CREATE PROCEDURE UpdateShiftStatus
    @ShiftAssignmentID INT,
    @Status VARCHAR(20)
AS
BEGIN
    UPDATE ShiftAssignment
    SET status = @Status
    WHERE assignment_id = @ShiftAssignmentID;

    SELECT 'Shift status updated to ' + @Status AS ConfirmationMessage;
END;
GO
-- 12. AssignShiftToDepartment
CREATE PROCEDURE AssignShiftToDepartment
    @DepartmentID INT,
    @ShiftID INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
    SELECT 
        e.employee_id,
        @ShiftID,
        @StartDate,
        @EndDate,
        'Active'
    FROM Employee e
    WHERE e.department_id = @DepartmentID
        AND e.is_active = 1;

    SELECT 'Shift assigned successfully to all employees in department ' + CAST(@DepartmentID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO
-- 13. AssignCustomShift
CREATE PROCEDURE AssignCustomShift
    @EmployeeID INT,
    @ShiftName VARCHAR(50),
    @ShiftType VARCHAR(50),
    @StartTime TIME,
    @EndTime TIME,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    INSERT INTO ShiftSchedule (name, type, start_time, end_time, status)
    VALUES (@ShiftName, @ShiftType, @StartTime, @EndTime, 'Active');

    INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
    VALUES (@EmployeeID, SCOPE_IDENTITY(), @StartDate, @EndDate, 'Active');

    SELECT 'Custom shift created and assigned successfully to employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO

-- 14. ConfigureSplitShift
CREATE PROCEDURE ConfigureSplitShift
    @ShiftName VARCHAR(50),
    @FirstSlotStart TIME,
    @FirstSlotEnd TIME,
    @SecondSlotStart TIME,
    @SecondSlotEnd TIME
AS
BEGIN
    INSERT INTO ShiftSchedule (name, type, start_time, end_time, break_duration, status)
    VALUES (
        @ShiftName + ' - Slot 1',
        'Split Shift',
        @FirstSlotStart,
        @FirstSlotEnd,
        DATEDIFF(MINUTE, @FirstSlotEnd, @SecondSlotStart),
        'Active'
    );

    INSERT INTO ShiftSchedule (name, type, start_time, end_time, status)
    VALUES (
        @ShiftName + ' - Slot 2',
        'Split Shift',
        @SecondSlotStart,
        @SecondSlotEnd,
        'Active'
    );

    SELECT 'Split shift configured successfully: ' + @ShiftName AS ConfirmationMessage;
END;
GO

-- 15. EnableFirstInLastOut
CREATE PROCEDURE EnableFirstInLastOut
    @Enable BIT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM PayrollPolicy WHERE [type] = 'Attendance Processing')
    BEGIN
        UPDATE PayrollPolicy
        SET [description] = CASE WHEN @Enable = 1 THEN 'First In/Last Out: Enabled' ELSE 'First In/Last Out: Disabled' END,
            effective_date = GETDATE()
        WHERE [type] = 'Attendance Processing';
    END
    ELSE
    BEGIN
        INSERT INTO PayrollPolicy (effective_date, [type], [description])
        VALUES (
            GETDATE(),
            'Attendance Processing',
            CASE WHEN @Enable = 1 THEN 'First In/Last Out: Enabled' ELSE 'First In/Last Out: Disabled' END
        );
    END

    SELECT CASE WHEN @Enable = 1 THEN 'First In/Last Out attendance processing enabled' ELSE 'First In/Last Out attendance processing disabled' END AS ConfirmationMessage;
END;
GO

-- 16. TagAttendanceSource
CREATE PROCEDURE TagAttendanceSource
    @AttendanceID INT,
    @SourceType VARCHAR(20),
    @DeviceID INT,
    @Latitude DECIMAL(10,7),
    @Longitude DECIMAL(10,7)
AS
BEGIN
    INSERT INTO AttendanceSource (attendance_id, device_id, source_type, latitude, longitude)
    VALUES (@AttendanceID, @DeviceID, @SourceType, @Latitude, @Longitude);

    SELECT 'Attendance source tagged successfully' AS ConfirmationMessage;
END;
GO

-- 17. SyncOfflineAttendance
CREATE PROCEDURE SyncOfflineAttendance
    @DeviceID INT,
    @EmployeeID INT,
    @ClockTime DATETIME,
    @Type VARCHAR(10)
AS
BEGIN
    IF @Type = 'IN'
    BEGIN
        INSERT INTO Attendance (employee_id, entry_time, login_method)
        VALUES (@EmployeeID, @ClockTime, 'Device');

        INSERT INTO AttendanceSource (attendance_id, device_id, source_type)
        VALUES (SCOPE_IDENTITY(), @DeviceID, 'Offline Sync');
    END
    ELSE IF @Type = 'OUT'
    BEGIN
        UPDATE Attendance
        SET exit_time = @ClockTime,
            logout_method = 'Device'
        WHERE employee_id = @EmployeeID
            AND CAST(entry_time AS DATE) = CAST(@ClockTime AS DATE)
            AND exit_time IS NULL;

        INSERT INTO AttendanceSource (attendance_id, device_id, source_type)
        SELECT TOP 1 attendance_id, @DeviceID, 'Offline Sync'
        FROM Attendance
        WHERE employee_id = @EmployeeID
            AND CAST(entry_time AS DATE) = CAST(@ClockTime AS DATE)
        ORDER BY entry_time DESC;
    END

    SELECT 'Offline attendance synced successfully' AS ConfirmationMessage;
END;
GO

-- 18. LogAttendanceEdit
CREATE PROCEDURE LogAttendanceEdit
    @AttendanceID INT,
    @EditedBy INT,
    @OldValue DATETIME,
    @NewValue DATETIME,
    @EditTimestamp DATETIME
AS
BEGIN
    INSERT INTO AttendanceLog (attendance_id, actor, [timestamp], reason)
    VALUES (
        @AttendanceID,
        @EditedBy,
        @EditTimestamp,
        'Clock edit: Changed from ' + CONVERT(VARCHAR(30), @OldValue, 120) + ' to ' + CONVERT(VARCHAR(30), @NewValue, 120)
    );

    SELECT 'Attendance edit logged successfully' AS ConfirmationMessage;
END;
GO

-- 19. ApplyHolidayOverrides
CREATE PROCEDURE ApplyHolidayOverrides
    @HolidayID INT,
    @EmployeeID INT
AS
BEGIN
    INSERT INTO Employee_Exception (employee_id, exception_id)
    SELECT 
        @EmployeeID,
        e.exception_id
    FROM Exception e
    INNER JOIN HolidayLeave hl ON e.[name] = hl.holiday_name
    WHERE hl.leave_id = @HolidayID
        AND NOT EXISTS (
            SELECT 1 
            FROM Employee_Exception ee 
            WHERE ee.employee_id = @EmployeeID 
                AND ee.exception_id = e.exception_id
        );

    SELECT 'Holiday override applied successfully to employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO
-- 20. ManageUserAccounts
CREATE PROCEDURE ManageUserAccounts
    @UserID INT,
    @Role VARCHAR(50),
    @Action VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RoleID INT;

    -- Get role ID from role name
    SELECT @RoleID = role_id
    FROM Role
    WHERE role_name = @Role;

    IF @RoleID IS NULL
    BEGIN
        SELECT 'Invalid role specified.' AS Message;
        RETURN;
    END

    IF @Action = 'Assign'
    BEGIN
        IF EXISTS (
            SELECT 1 FROM Employee_Role
            WHERE employee_id = @UserID AND role_id = @RoleID
        )
        BEGIN
            SELECT 'User already has this role.' AS Message;
            RETURN;
        END

        INSERT INTO Employee_Role (employee_id, role_id, assigned_date)
        VALUES (@UserID, @RoleID, GETDATE());

        SELECT 'Role assigned successfully.' AS Message;
        RETURN;
    END

    IF @Action = 'Remove'
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM Employee_Role
            WHERE employee_id = @UserID AND role_id = @RoleID
        )
        BEGIN
            SELECT 'Role was not assigned to this user.' AS Message;
            RETURN;
        END

        DELETE FROM Employee_Role
        WHERE employee_id = @UserID AND role_id = @RoleID;

        SELECT 'Role removed successfully.' AS Message;
        RETURN;
    END

    SELECT 'Invalid action. Use Assign or Remove.' AS Message;
END;
GO