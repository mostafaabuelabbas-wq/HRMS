USE HRMS
GO
--HR admin
--1  CreateContract
CREATE PROCEDURE CreateContract
    @EmployeeID INT,
    @Type VARCHAR(50),
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validate employee exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 2. Validate dates
        IF (@StartDate >= @EndDate)
        BEGIN
            RAISERROR('StartDate must be earlier than EndDate.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 3. Insert Contract
        INSERT INTO Contract (type, start_date, end_date, current_state)
        VALUES (@Type, @StartDate, @EndDate, 'Active');

        DECLARE @NewContractID INT = SCOPE_IDENTITY();

        -- 4. Insert into contract subtype
        IF (@Type = 'FullTime')
            INSERT INTO FullTimeContract (contract_id, leave_entitlement, insurance_eligibility, weekly_working_hours)
            VALUES (@NewContractID, 21, 1, 40);

        ELSE IF (@Type = 'PartTime')
            INSERT INTO PartTimeContract (contract_id, working_hours, hourly_rate)
            VALUES (@NewContractID, 20, 150);

        ELSE IF (@Type = 'Consultant')
            INSERT INTO ConsultantContract (contract_id, project_scope, fees, payment_schedule)
            VALUES (@NewContractID, 'General Project', 0, 'Monthly');

        ELSE IF (@Type = 'Internship')
            INSERT INTO InternshipContract (contract_id, mentoring, evaluation, stipend_related)
            VALUES (@NewContractID, 'Mentoring Program', 'Evaluation', 'Stipend');

        ELSE
        BEGIN
            RAISERROR('Invalid contract type.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- 5. Assign contract to employee
        UPDATE Employee
        SET contract_id = @NewContractID
        WHERE employee_id = @EmployeeID;

        COMMIT TRANSACTION;

        SELECT 'Contract created successfully. ContractID = ' 
               + CAST(@NewContractID AS VARCHAR(10))
               AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO





-- 2 RenewContract
CREATE PROCEDURE RenewContract
    @ContractID INT,
    @NewEndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Check if contract exists and retrieve start date
    DECLARE @StartDate DATE;
    SELECT @StartDate = start_date 
    FROM Contract 
    WHERE contract_id = @ContractID;

    IF @StartDate IS NULL
    BEGIN
        SELECT 'Error: Contract not found' AS ConfirmationMessage;
        RETURN;
    END

    -- 2. Validate end date
    IF @NewEndDate <= @StartDate
    BEGIN
        SELECT 'Error: New end date must be after start date' AS ConfirmationMessage;
        RETURN;
    END

    -- 3. Update
    UPDATE Contract
    SET end_date = @NewEndDate,
        current_state = 'Active'
    WHERE contract_id = @ContractID;

    SELECT 'Contract renewed successfully' AS ConfirmationMessage;
END;
GO


-- 3  ApproveLeaveRequest
CREATE PROCEDURE ApproveLeaveRequest
    @LeaveRequestID INT,
    @ApproverID INT,
    @Status VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @LeaveID INT;
        DECLARE @EmployeeID INT;
        DECLARE @LeaveType VARCHAR(50);

        -- Validate request exists
        IF NOT EXISTS (SELECT 1 FROM LeaveRequest WHERE request_id = @LeaveRequestID)
        BEGIN
            RAISERROR('Leave request does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate approver exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ApproverID)
        BEGIN
            RAISERROR('Approver does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Fetch request data
        SELECT 
            @LeaveID = leave_id,
            @EmployeeID = employee_id
        FROM LeaveRequest
        WHERE request_id = @LeaveRequestID;

        -- Get leave type
        SELECT @LeaveType = leave_type
        FROM [Leave]
        WHERE leave_id = @LeaveID;

        -- Update request status
        UPDATE LeaveRequest
        SET status = @Status,
            approval_timing = GETDATE()
        WHERE request_id = @LeaveRequestID;

        -- Update subtype table IF Vacation leave
        IF @LeaveType = 'Vacation'
        BEGIN
            UPDATE VacationLeave
            SET approving_manager = @ApproverID
            WHERE leave_id = @LeaveID;
        END

        -- Create notification
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'Your leave request has been ' + @Status,
            'Medium',
            0,
            'Leave'
        );

        DECLARE @NotificationID INT = SCOPE_IDENTITY();

        -- Assign notification to employee
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@EmployeeID, @NotificationID, 'Sent', GETDATE());

        COMMIT TRANSACTION;

        SELECT 'Leave request ' + @Status + ' successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



-- 4 AssignMission
-- PROCEDURE: AssignMission
CREATE PROCEDURE AssignMission
    @EmployeeID INT,
    @ManagerID INT,
    @Destination VARCHAR(50),
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate employee exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate manager exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
        BEGIN
            RAISERROR('Manager does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate date range
        IF (@StartDate >= @EndDate)
        BEGIN
            RAISERROR('StartDate must be earlier than EndDate.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Insert mission
        INSERT INTO Mission (destination, start_date, end_date, status, employee_id, manager_id)
        VALUES (@Destination, @StartDate, @EndDate, 'Assigned', @EmployeeID, @ManagerID);

        -- Create notification
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'You have been assigned a mission to ' + @Destination +
            ' from ' + CONVERT(VARCHAR(10), @StartDate, 120) +
            ' to ' + CONVERT(VARCHAR(10), @EndDate, 120),
            'High',
            0,
            'Mission Assignment'
        );

        DECLARE @NotificationID INT = SCOPE_IDENTITY();

        -- Assign notification to employee
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@EmployeeID, @NotificationID, 'Sent', GETDATE());

        COMMIT TRANSACTION;

        SELECT 'Mission assigned successfully to employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



-- 5 ReviewReimbursement
CREATE PROCEDURE ReviewReimbursement
    @ClaimID INT,
    @ApproverID INT,
    @Decision VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EmployeeID INT;
        DECLARE @Type VARCHAR(50);

        -- Validate reimbursement exists
        IF NOT EXISTS (SELECT 1 FROM Reimbursement WHERE reimbursement_id = @ClaimID)
        BEGIN
            RAISERROR('Reimbursement claim does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate approver exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ApproverID)
        BEGIN
            RAISERROR('Approver does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Get employee and claim type
        SELECT 
            @EmployeeID = employee_id,
            @Type = type
        FROM Reimbursement
        WHERE reimbursement_id = @ClaimID;

        -- Update reimbursement
        UPDATE Reimbursement
        SET current_status = @Decision,
            approval_date = GETDATE()
        WHERE reimbursement_id = @ClaimID;

        -- Create notification
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'Your reimbursement claim for ' + @Type + ' has been ' + @Decision,
            'Medium',
            0,
            'Reimbursement'
        );

        DECLARE @NotificationID INT = SCOPE_IDENTITY();

        -- Assign notification to employee
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (@EmployeeID, @NotificationID, 'Sent', GETDATE());

        COMMIT TRANSACTION;

        SELECT 'Reimbursement claim ' + @Decision + ' successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO




-- 6 GetActiveContracts
-- PROCEDURE: GetActiveContracts
CREATE PROCEDURE GetActiveContracts
AS
BEGIN
    SET NOCOUNT ON;

    -- return all active contracts with employee & department data
    SELECT 
        c.contract_id,
        c.type,
        c.start_date,
        c.end_date,
        c.current_state,
        e.employee_id,
        e.full_name,
        e.department_id,
        d.department_name
    FROM Contract c
    INNER JOIN Employee e ON c.contract_id = e.contract_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    WHERE c.current_state = 'Active';
END;
GO

-- 7 GetTeamByManager
-- PROCEDURE: GetTeamByManager
CREATE PROCEDURE GetTeamByManager
    @ManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Return all active employees reporting to a specific manager
    SELECT 
        e.employee_id,
        e.full_name,  -- use computed column instead of manual concat
        e.position_id,
        p.position_title,
        e.department_id,
        d.department_name,
        e.employment_status
    FROM Employee e
    LEFT JOIN Position p ON e.position_id = p.position_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    WHERE e.manager_id = @ManagerID 
      AND e.is_active = 1
    ORDER BY e.full_name;
END;
GO


-- 8 UpdateLeavePolicy
-- PROCEDURE: UpdateLeavePolicy
CREATE PROCEDURE UpdateLeavePolicy
    @PolicyID INT,
    @EligibilityRules VARCHAR(200),
    @NoticePeriod INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate policy exists
        IF NOT EXISTS (SELECT 1 FROM LeavePolicy WHERE policy_id = @PolicyID)
        BEGIN
            RAISERROR('Leave policy does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Update the policy
        UPDATE LeavePolicy
        SET eligibility_rules = @EligibilityRules,
            notice_period = @NoticePeriod
        WHERE policy_id = @PolicyID;

        COMMIT TRANSACTION;

        SELECT 'Leave policy updated successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO


-- 9 GetExpiringContracts
-- PROCEDURE: GetExpiringContracts
CREATE PROCEDURE GetExpiringContracts
    @DaysBefore INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Return contracts that will expire within the next @DaysBefore days
    SELECT 
        c.contract_id,
        c.type,
        c.start_date,
        c.end_date,
        e.employee_id,
        e.full_name,
        d.department_name,
        DATEDIFF(DAY, GETDATE(), c.end_date) AS days_until_expiration
    FROM Contract c
    INNER JOIN Employee e ON c.contract_id = e.contract_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    WHERE c.end_date > GETDATE()            -- must be in the future
      AND c.end_date <= DATEADD(DAY, @DaysBefore, GETDATE())
    ORDER BY c.end_date;
END;
GO

-- 10 AssignDepartmentHead
-- PROCEDURE: AssignDepartmentHead
CREATE PROCEDURE AssignDepartmentHead
    @DepartmentID INT,
    @ManagerID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate department exists
        IF NOT EXISTS (SELECT 1 FROM Department WHERE department_id = @DepartmentID)
        BEGIN
            RAISERROR('Department does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate manager exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @ManagerID)
        BEGIN
            RAISERROR('Manager (employee) does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Update department head
        UPDATE Department
        SET department_head_id = @ManagerID
        WHERE department_id = @DepartmentID;

        COMMIT TRANSACTION;

        SELECT 'Department head assigned successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO


-- 11 CreateEmployeeProfile
-- PROCEDURE: CreateEmployeeProfile
CREATE PROCEDURE CreateEmployeeProfile
    @FirstName VARCHAR(50),
    @LastName VARCHAR(50),
    @DepartmentID INT,
    @RoleID INT,                -- maps to Position.position_id
    @HireDate DATE,
    @Email VARCHAR(100),
    @Phone VARCHAR(20),
    @NationalID VARCHAR(50),
    @DateOfBirth DATE,
    @CountryOfBirth VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate department exists
        IF NOT EXISTS (SELECT 1 FROM Department WHERE department_id = @DepartmentID)
        BEGIN
            RAISERROR('Department does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate position exists
        IF NOT EXISTS (SELECT 1 FROM Position WHERE position_id = @RoleID)
        BEGIN
            RAISERROR('Position (RoleID) does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate unique email
        IF EXISTS (SELECT 1 FROM Employee WHERE email = @Email)
        BEGIN
            RAISERROR('Email already exists for another employee.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Insert new employee profile
        INSERT INTO Employee (
            first_name,
            last_name,
            national_id,
            date_of_birth,
            country_of_birth,
            email,
            phone,
            department_id,
            position_id,
            hire_date,
            is_active,
            profile_completion,
            account_status,
            employment_status
        )
        VALUES (
            @FirstName,
            @LastName,
            @NationalID,
            @DateOfBirth,
            @CountryOfBirth,
            @Email,
            @Phone,
            @DepartmentID,
            @RoleID,
            @HireDate,
            1,                 -- active
            0,                 -- profile incomplete
            'Active',
            'Full-time'
        );

        DECLARE @NewEmployeeID INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT 
            @NewEmployeeID AS EmployeeID,
            'Employee profile created successfully.' AS Message;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO



-- 12 UpdateEmployeeProfile
-- PROCEDURE: UpdateEmployeeProfile
CREATE PROCEDURE UpdateEmployeeProfile
    @EmployeeID INT,
    @FieldName VARCHAR(50),
    @NewValue VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate employee exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------------------------
        -- VALID FIELD LIST (PREVENTS SQL INJECTION & INVALID COLUMN ERRORS)
        ----------------------------------------------------------------------
        DECLARE @AllowedFields TABLE (field_name VARCHAR(50));
        INSERT INTO @AllowedFields VALUES
            ('first_name'),
            ('last_name'),
            ('email'),
            ('phone'),
            ('address'),
            ('emergency_contact_name'),
            ('emergency_contact_phone'),
            ('biography'),
            ('employment_status'),
            ('account_status');

        IF NOT EXISTS (SELECT 1 FROM @AllowedFields WHERE field_name = @FieldName)
        BEGIN
            RAISERROR('Invalid or unauthorized field name.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------------------------
        -- PREVENT DUPLICATE EMAILS
        ----------------------------------------------------------------------
        IF @FieldName = 'email'
        BEGIN
            IF EXISTS (SELECT 1 FROM Employee WHERE email = @NewValue AND employee_id <> @EmployeeID)
            BEGIN
                RAISERROR('Email already exists for another employee.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END;
        END;

        ----------------------------------------------------------------------
        -- DYNAMIC SQL TO UPDATE ONLY VALID FIELD NAMES
        ----------------------------------------------------------------------
        DECLARE @SQL NVARCHAR(MAX) =
            N'UPDATE Employee SET ' + QUOTENAME(@FieldName) + N' = @Value WHERE employee_id = @ID';

        EXEC sys.sp_executesql 
            @SQL,
            N'@Value VARCHAR(255), @ID INT',
            @Value = @NewValue,
            @ID = @EmployeeID;

        COMMIT TRANSACTION;

        SELECT 'Employee profile updated successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



-- 13 SetProfileCompleteness
-- PROCEDURE: SetProfileCompleteness
CREATE PROCEDURE SetProfileCompleteness
    @EmployeeID INT,
    @CompletenessPercentage INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate employee exists
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate range (0–100)
        IF @CompletenessPercentage < 0 OR @CompletenessPercentage > 100
        BEGIN
            RAISERROR('Completeness percentage must be between 0 and 100.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Update completeness
        UPDATE Employee
        SET profile_completion = @CompletenessPercentage
        WHERE employee_id = @EmployeeID;

        COMMIT TRANSACTION;

        SELECT 
            'Profile completeness updated to ' 
            + CAST(@CompletenessPercentage AS VARCHAR(10)) + '%' AS ConfirmationMessage,
            @CompletenessPercentage AS UpdatedCompleteness;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO


-- 14 GenerateProfileReport
-- PROCEDURE: GenerateProfileReport
CREATE PROCEDURE GenerateProfileReport
    @FilterField VARCHAR(50),
    @FilterValue VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    --------------------------------------------------------------------
    -- VALIDATION OF ALLOWED FILTER FIELDS (prevents SQL injection)
    --------------------------------------------------------------------
    DECLARE @Allowed TABLE (FieldName VARCHAR(50));
    INSERT INTO @Allowed VALUES
        ('department'),
        ('employment_status'),
        ('country_of_birth'),
        ('all');

    IF NOT EXISTS (SELECT 1 FROM @Allowed WHERE FieldName = @FilterField)
    BEGIN
        RAISERROR('Invalid filter field.', 16, 1);
        RETURN;
    END;

    --------------------------------------------------------------------
    -- RETURN ALL EMPLOYEES IF FILTER = 'all'
    --------------------------------------------------------------------
    IF @FilterField = 'all'
    BEGIN
        SELECT 
            e.employee_id,
            e.full_name,
            e.email,
            e.phone,
            e.country_of_birth,
            d.department_name,
            p.position_title,
            e.hire_date,
            e.employment_status
        FROM Employee e
        LEFT JOIN Department d ON e.department_id = d.department_id
        LEFT JOIN Position p ON e.position_id = p.position_id;
        
        RETURN;
    END;

    --------------------------------------------------------------------
    -- FILTER BY SPECIFIC FIELDS
    --------------------------------------------------------------------
    SELECT 
        e.employee_id,
        e.full_name,
        e.email,
        e.phone,
        e.country_of_birth,
        d.department_name,
        p.position_title,
        e.hire_date,
        e.employment_status
    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    WHERE 
        (@FilterField = 'department' AND d.department_name = @FilterValue)
        OR (@FilterField = 'employment_status' AND e.employment_status = @FilterValue)
        OR (@FilterField = 'country_of_birth' AND e.country_of_birth = @FilterValue);
END;
GO


-- 15 CreateShiftType
-- PROCEDURE: CreateShiftType
CREATE PROCEDURE CreateShiftType
    @ShiftID INT,
    @Name VARCHAR(100),
    @Type VARCHAR(50),
    @Start_Time TIME,
    @End_Time TIME,
    @Break_Duration INT,
    @Shift_Date DATE,
    @Status VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- If ShiftID is provided (not null), check if it exists
        IF EXISTS (SELECT 1 FROM ShiftSchedule WHERE shift_id = @ShiftID)
        BEGIN
            RAISERROR('Shift ID already exists. Use a new ID or an auto-generated ID.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Insert into ShiftSchedule
        INSERT INTO ShiftSchedule
        (
            name,
            type,
            start_time,
            end_time,
            break_duration,
            shift_date,
            status
        )
        VALUES
        (
            @Name,
            @Type,
            @Start_Time,
            @End_Time,
            @Break_Duration,
            @Shift_Date,
            @Status
        );

        DECLARE @NewShiftID INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT 
            @NewShiftID AS ShiftID,
            'Shift type created successfully.' AS Message;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



-- 17 AssignRotationalShift
-- PROCEDURE: AssignRotationalShift
CREATE PROCEDURE AssignRotationalShift
    @EmployeeID INT,
    @ShiftCycle INT,
    @StartDate DATE,
    @EndDate DATE,
    @Status VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------------------
        -- Validate employee exists
        ------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------------
        -- Validate shift cycle exists
        ------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM ShiftCycle WHERE cycle_id = @ShiftCycle)
        BEGIN
            RAISERROR('Shift cycle does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------------
        -- Validate cycle has shift assignments
        ------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM ShiftCycleAssignment WHERE cycle_id = @ShiftCycle)
        BEGIN
            RAISERROR('Shift cycle has no assigned shifts.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------------
        -- Insert one record per shift in the cycle (Morning/Evening/Night…)
        ------------------------------------------------------------------
        INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, end_date, status)
        SELECT 
            @EmployeeID,
            sca.shift_id,
            @StartDate,
            @EndDate,
            @Status
        FROM ShiftCycleAssignment sca
        WHERE sca.cycle_id = @ShiftCycle
        ORDER BY sca.order_number;

        ------------------------------------------------------------------
        -- Return confirmation
        ------------------------------------------------------------------
        SELECT 
            'Rotational shift assigned successfully to employee ' +
            CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 18 NotifyShiftExpiry
-- PROCEDURE: NotifyShiftExpiry
CREATE PROCEDURE NotifyShiftExpiry
    @EmployeeID INT,
    @ShiftAssignmentID INT,
    @ExpiryDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------------
        -- Validate Employee
        ------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------
        -- Validate Shift Assignment
        ------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM ShiftAssignment WHERE assignment_id = @ShiftAssignmentID)
        BEGIN
            RAISERROR('Shift assignment does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------
        -- Create Notification
        ------------------------------------------------------------
        INSERT INTO Notification (message_content, urgency, read_status, notification_type)
        VALUES (
            'Your shift assignment ID ' + CAST(@ShiftAssignmentID AS VARCHAR(20)) +
            ' is expiring on ' + CONVERT(VARCHAR(10), @ExpiryDate, 120),
            'High',
            0,
            'Shift Expiry'
        );

        DECLARE @NotifID INT = SCOPE_IDENTITY();

        ------------------------------------------------------------
        -- Assign notification to employee
        ------------------------------------------------------------
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (
            @EmployeeID,
            @NotifID,
            'Pending',
            GETDATE()
        );

        COMMIT TRANSACTION;

        SELECT 'Shift expiry notification sent successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 19 DefineShortTimeRules
-- PROCEDURE: DefineShortTimeRules
CREATE PROCEDURE DefineShortTimeRules
    @RuleName VARCHAR(50),
    @LateMinutes INT,
    @EarlyLeaveMinutes INT,
    @PenaltyType VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validate rule name
        IF LEN(@RuleName) = 0
        BEGIN
            RAISERROR('Rule name cannot be empty.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Validate minutes
        IF @LateMinutes < 0 OR @EarlyLeaveMinutes < 0
        BEGIN
            RAISERROR('Minutes cannot be negative.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Insert into PayrollPolicy
        INSERT INTO PayrollPolicy (effective_date, type, description)
        VALUES (
            GETDATE(),
            'Short Time',
            @RuleName + ' - Late penalty after ' + CAST(@LateMinutes AS VARCHAR(10)) +
            ' mins, Early leave penalty after ' + CAST(@EarlyLeaveMinutes AS VARCHAR(10)) +
            ' mins. Penalty type: ' + @PenaltyType
        );

        DECLARE @NewPolicyID INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT 
            @NewPolicyID AS PolicyID,
            'Short time rule defined successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 20 SetGracePeriod
-- PROCEDURE: SetGracePeriod
CREATE PROCEDURE SetGracePeriod
    @Minutes INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------------
        -- Validate minutes
        ------------------------------------------------------------
        IF @Minutes < 0
        BEGIN
            RAISERROR('Grace minutes cannot be negative.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------
        -- Insert into PayrollPolicy
        ------------------------------------------------------------
        INSERT INTO PayrollPolicy (effective_date, type, description)
        VALUES (
            GETDATE(),
            'Lateness',
            'Grace period: First ' + CAST(@Minutes AS VARCHAR(10)) +
            ' minutes of lateness tolerated'
        );

        DECLARE @PolicyID INT = SCOPE_IDENTITY();

        ------------------------------------------------------------
        -- Insert into LatenessPolicy (required by schema)
        ------------------------------------------------------------
        INSERT INTO LatenessPolicy (policy_id, grace_period_mins, deduction_rate)
        VALUES (
            @PolicyID,
            @Minutes,
            0.00   -- No deduction during grace period
        );

        COMMIT TRANSACTION;

        SELECT 
            @PolicyID AS PolicyID,
            'Grace period set successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 21 DefinePenaltyThreshold
-- PROCEDURE: DefinePenaltyThreshold
CREATE PROCEDURE DefinePenaltyThreshold
    @LateMinutes INT,
    @DeductionType VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------------
        -- VALIDATIONS
        ------------------------------------------------------------

        -- Late minutes cannot be negative
        IF @LateMinutes < 0
        BEGIN
            RAISERROR('LateMinutes cannot be negative.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Deduction type must not be empty
        IF LEN(@DeductionType) = 0
        BEGIN
            RAISERROR('DeductionType cannot be empty.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------
        -- 1. Insert into PayrollPolicy
        ------------------------------------------------------------
        INSERT INTO PayrollPolicy (effective_date, type, description)
        VALUES (
            GETDATE(),
            'Lateness Penalty',
            'Penalty threshold: Lateness over ' + CAST(@LateMinutes AS VARCHAR(10)) +
            ' minutes. Deduction type: ' + @DeductionType
        );

        DECLARE @PolicyID INT = SCOPE_IDENTITY();

        ------------------------------------------------------------
        -- 2. Insert into DeductionPolicy (linked to PayrollPolicy)
        ------------------------------------------------------------
        INSERT INTO DeductionPolicy (policy_id, deduction_reason, calculation_mode)
        VALUES (
            @PolicyID,
            @DeductionType,
            'LateMinutes>' + CAST(@LateMinutes AS VARCHAR(10))
        );

        ------------------------------------------------------------
        -- SUCCESS
        ------------------------------------------------------------
        COMMIT TRANSACTION;

        SELECT 
            @PolicyID AS PolicyID,
            'Penalty threshold defined successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO


-- 22 DefinePermissionLimits
-- PROCEDURE: DefinePermissionLimits
CREATE PROCEDURE DefinePermissionLimits
    @MinHours INT,
    @MaxHours INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------------
        -- VALIDATION
        ----------------------------------------------------------

        -- Hours cannot be negative
        IF @MinHours < 0 OR @MaxHours < 0
        BEGIN
            RAISERROR('Hours cannot be negative.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -- Max must be >= Min
        IF @MaxHours < @MinHours
        BEGIN
            RAISERROR('MaxHours must be greater than or equal to MinHours.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ----------------------------------------------------------
        -- INSERT INTO PayrollPolicy
        ----------------------------------------------------------
        INSERT INTO PayrollPolicy (effective_date, type, description)
        VALUES (
            GETDATE(),
            'Permission Limits',
            'Permission limits: MinHours=' + CAST(@MinHours AS VARCHAR(10)) +
            ', MaxHours=' + CAST(@MaxHours AS VARCHAR(10))
        );

        DECLARE @NewPolicyID INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT 
            @NewPolicyID AS PolicyID,
            'Permission limits defined successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO

-- 23 EscalatePendingRequests
-- PROCEDURE: EscalatePendingRequests
CREATE PROCEDURE EscalatePendingRequests
    @Deadline DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -------------------------------------------------------
        -- VALIDATION
        -------------------------------------------------------
        IF @Deadline IS NULL
        BEGIN
            RAISERROR('Deadline cannot be NULL.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -------------------------------------------------------
        -- ESCALATE LEAVE REQUESTS
        -------------------------------------------------------
        UPDATE LeaveRequest
        SET status = 'Escalated'
        WHERE status = 'Pending'
          AND (approval_timing IS NULL OR approval_timing < @Deadline);

        DECLARE @EscLeave INT = @@ROWCOUNT;

        -------------------------------------------------------
        -- ESCALATE ATTENDANCE CORRECTIONS
        -------------------------------------------------------
        UPDATE AttendanceCorrectionRequest
        SET status = 'Escalated'
        WHERE status = 'Pending'
          AND [date] < @Deadline;

        DECLARE @EscAttend INT = @@ROWCOUNT;

        -------------------------------------------------------
        -- ESCALATE REIMBURSEMENT CLAIMS
        -------------------------------------------------------
        UPDATE Reimbursement
        SET current_status = 'Escalated'
        WHERE current_status = 'Pending'
          AND (approval_date IS NULL OR approval_date < @Deadline);

        DECLARE @EscReimb INT = @@ROWCOUNT;

        -------------------------------------------------------
        -- FINAL OUTPUT
        -------------------------------------------------------
        COMMIT TRANSACTION;

        SELECT 
            'Pending requests escalated successfully' AS ConfirmationMessage,
            @EscLeave AS EscalatedLeaveRequests,
            @EscAttend AS EscalatedAttendanceCorrections,
            @EscReimb AS EscalatedReimbursements;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- 24 LinkVacationToShift
-- PROCEDURE: LinkVacationToShift
CREATE PROCEDURE LinkVacationToShift
    @VacationPackageID INT,
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -----------------------------------------------------------
        -- 1. Validate Employee Exists
        -----------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -----------------------------------------------------------
        -- 2. Get Vacation Leave Type ID
        -----------------------------------------------------------
        DECLARE @LeaveTypeID INT;

        SELECT TOP 1 @LeaveTypeID = leave_id
        FROM [Leave]
        WHERE leave_type LIKE '%Vacation%';

        IF @LeaveTypeID IS NULL
        BEGIN
            RAISERROR('Vacation leave type does not exist in the system.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        -----------------------------------------------------------
        -- 3. Create Leave Entitlement if not exists
        -----------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 FROM LeaveEntitlement
            WHERE employee_id = @EmployeeID
              AND leave_type_id = @LeaveTypeID
        )
        BEGIN
            INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
            VALUES (@EmployeeID, @LeaveTypeID, 0);
        END

        -----------------------------------------------------------
        -- 4. Link vacation package to employee SHIFTS
        -- Mark all shift assignments as 'Vacation' for the package
        -----------------------------------------------------------
        UPDATE ShiftAssignment
        SET status = 'Vacation'
        WHERE employee_id = @EmployeeID;

        -----------------------------------------------------------
        -- 5. Return Confirmation
        -----------------------------------------------------------
        COMMIT TRANSACTION;

        SELECT 'Vacation package linked to employee schedule successfully.' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO



-- 25 ConfigureLeavePolicies
-- PROCEDURE: ConfigureLeavePolicies
CREATE PROCEDURE ConfigureLeavePolicies
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------
        -- Check if default leave policy already exists
        ------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 
            FROM LeavePolicy 
            WHERE name = 'Default Leave Policy'
        )
        BEGIN
            INSERT INTO LeavePolicy 
                (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year)
            VALUES (
                'Default Leave Policy',
                'Standard leave configuration',
                'All employees eligible',
                7,
                'Standard',
                1
            );
        END

        COMMIT TRANSACTION;

        SELECT 
            'Leave policies configured successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH

END;
GO



-- 26 AuthenticateLeaveAdmin
-- PROCEDURE: AuthenticateLeaveAdmin
CREATE PROCEDURE AuthenticateLeaveAdmin
    @AdminID INT,
    @Password VARCHAR(100)   -- Provided for signature only, not used
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------
    -- 1. Validate employee exists
    -------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @AdminID)
    BEGIN
        SELECT 'Authentication failed: Employee does not exist.' AS Message;
        RETURN;
    END;

    -------------------------------------------------------------
    -- 2. Validate employee is an HR Administrator
    -------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM HRAdministrator WHERE employee_id = @AdminID)
    BEGIN
        SELECT 'Authentication failed: Employee is not an HR Administrator.' AS Message;
        RETURN;
    END;

    -------------------------------------------------------------
    -- 3. Successful authentication (role-based)
    -------------------------------------------------------------
    SELECT 
        e.employee_id,
        e.full_name,
        hr.approval_level,
        'Administrator authenticated successfully' AS Message
    FROM Employee e
    INNER JOIN HRAdministrator hr ON e.employee_id = hr.employee_id
    WHERE e.employee_id = @AdminID;
END;
GO

-- 27 ApplyLeaveConfiguration
CREATE PROCEDURE ApplyLeaveConfiguration
AS
BEGIN
    -- Apply vacation leave (21 days)
    INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
    SELECT 
        e.employee_id,
        vl.leave_id,
        21.00
    FROM Employee e
    CROSS JOIN VacationLeave vl
    WHERE e.is_active = 1
    AND NOT EXISTS (
        SELECT 1 FROM LeaveEntitlement le 
        WHERE le.employee_id = e.employee_id 
        AND le.leave_type_id = vl.leave_id
    );

    -- Apply sick leave (10 days)
    INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
    SELECT 
        e.employee_id,
        sl.leave_id,
        10.00
    FROM Employee e
    CROSS JOIN SickLeave sl
    WHERE e.is_active = 1
    AND NOT EXISTS (
        SELECT 1 FROM LeaveEntitlement le 
        WHERE le.employee_id = e.employee_id 
        AND le.leave_type_id = sl.leave_id
    );

    -- Apply probation leave (5 days)
    INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
    SELECT 
        e.employee_id,
        pl.leave_id,
        5.00
    FROM Employee e
    CROSS JOIN ProbationLeave pl
    WHERE e.is_active = 1
    AND NOT EXISTS (
        SELECT 1 FROM LeaveEntitlement le 
        WHERE le.employee_id = e.employee_id 
        AND le.leave_type_id = pl.leave_id
    );

    -- Apply holiday leave (0 days - marked by calendar)
    INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
    SELECT 
        e.employee_id,
        hl.leave_id,
        0.00
    FROM Employee e
    CROSS JOIN HolidayLeave hl
    WHERE e.is_active = 1
    AND NOT EXISTS (
        SELECT 1 FROM LeaveEntitlement le 
        WHERE le.employee_id = e.employee_id 
        AND le.leave_type_id = hl.leave_id
    );

    SELECT 'Leave configuration applied successfully' AS ConfirmationMessage;
END;
GO
-- 28 UpdateLeaveEntitlements
-- PROCEDURE: UpdateLeaveEntitlements
CREATE PROCEDURE UpdateLeaveEntitlements
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------------
        -- Validate employee exists
        ------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Employee WHERE employee_id = @EmployeeID)
        BEGIN
            RAISERROR('Employee does not exist.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        ------------------------------------------------------------
        -- Get employee contract type safely
        ------------------------------------------------------------
        DECLARE @ContractType VARCHAR(50);

        SELECT @ContractType = c.type
        FROM Employee e
        LEFT JOIN Contract c ON e.contract_id = c.contract_id
        WHERE e.employee_id = @EmployeeID;

        ------------------------------------------------------------
        -- Remove existing entitlements
        ------------------------------------------------------------
        DELETE FROM LeaveEntitlement
        WHERE employee_id = @EmployeeID;

        ------------------------------------------------------------
        -- VACATION: FullTime = 21 days, PartTime = 10 days
        ------------------------------------------------------------
        IF @ContractType = 'FullTime'
        BEGIN
            INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
            SELECT @EmployeeID, leave_id, 21
            FROM VacationLeave;
        END
        ELSE IF @ContractType = 'PartTime'
        BEGIN
            INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
            SELECT @EmployeeID, leave_id, 10
            FROM VacationLeave;
        END

        ------------------------------------------------------------
        -- SICK: FullTime or PartTime → 10 days
        ------------------------------------------------------------
        IF @ContractType IN ('FullTime', 'PartTime')
        BEGIN
            INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
            SELECT @EmployeeID, leave_id, 10
            FROM SickLeave;
        END

        ------------------------------------------------------------
        -- PROBATION: employees hired within last 6 months
        ------------------------------------------------------------
        IF EXISTS (
            SELECT 1 FROM Employee 
            WHERE employee_id = @EmployeeID
              AND DATEDIFF(MONTH, hire_date, GETDATE()) <= 6
        )
        BEGIN
            INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
            SELECT @EmployeeID, leave_id, 5
            FROM ProbationLeave;
        END

        ------------------------------------------------------------
        -- HOLIDAY: Everybody → 0 days
        ------------------------------------------------------------
        IF EXISTS (SELECT 1 FROM HolidayLeave)
        BEGIN
            INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
            SELECT @EmployeeID, leave_id, 0
            FROM HolidayLeave;
        END

        COMMIT TRANSACTION;

        SELECT 'Leave entitlements updated successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


--29 ConfigureLeaveEligibility
CREATE PROCEDURE ConfigureLeaveEligibility
    @LeaveType VARCHAR(50),
    @MinTenure INT,
    @EmployeeType VARCHAR(50)
AS
BEGIN
    INSERT INTO LeavePolicy (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year)
    VALUES (
        @LeaveType + ' Eligibility Policy',
        'Eligibility configuration for ' + @LeaveType,
        'MinTenure=' + CAST(@MinTenure AS VARCHAR(10)) + ';EmployeeType=' + @EmployeeType,
        7,
        @LeaveType,
        1
    );

    SELECT 'Leave eligibility configured successfully' AS ConfirmationMessage;
END;
GO
-- 30 ManageLeaveTypes
-- PROCEDURE: ManageLeaveTypes
CREATE PROCEDURE ManageLeaveTypes
    @LeaveType VARCHAR(50),
    @Description VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        ------------------------------------------------------
        -- 1. Check if leave type already exists
        ------------------------------------------------------
        IF EXISTS (SELECT 1 FROM [Leave] WHERE leave_type = @LeaveType)
        BEGIN
            -- Update existing leave description
            UPDATE [Leave]
            SET leave_description = @Description
            WHERE leave_type = @LeaveType;

            COMMIT TRANSACTION;

            SELECT 'Leave type updated successfully' AS ConfirmationMessage;
            RETURN;
        END

        ------------------------------------------------------
        -- 2. Insert new leave type
        ------------------------------------------------------
        INSERT INTO [Leave] (leave_type, leave_description)
        VALUES (@LeaveType, @Description);

        COMMIT TRANSACTION;

        SELECT 'New leave type created successfully' AS ConfirmationMessage;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT 'Error: Leave type could not be created or updated.' AS ConfirmationMessage;
    END CATCH

END;
GO



--31 AssignLeaveEntitlement
CREATE PROCEDURE AssignLeaveEntitlement
    @EmployeeID INT,
    @LeaveType VARCHAR(50),
    @Entitlement DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LeaveTypeID INT;
    SELECT @LeaveTypeID = leave_id FROM [Leave] WHERE leave_type = @LeaveType;

    IF EXISTS (
        SELECT 1 FROM LeaveEntitlement
        WHERE employee_id = @EmployeeID AND leave_type_id = @LeaveTypeID
    )
    BEGIN
        UPDATE LeaveEntitlement
        SET entitlement = @Entitlement
        WHERE employee_id = @EmployeeID AND leave_type_id = @LeaveTypeID;

        SELECT 'Entitlement updated.' AS Message;
        RETURN;
    END

    INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
    VALUES (@EmployeeID, @LeaveTypeID, @Entitlement);

    SELECT 'Entitlement assigned.' AS Message;
END;
GO


--32 ConfigureLeaveRules
CREATE PROCEDURE ConfigureLeaveRules
    @LeaveType VARCHAR(50),
    @MaxDuration INT,
    @NoticePeriod INT,
    @WorkflowType VARCHAR(50)
AS
BEGIN
    INSERT INTO LeavePolicy (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year)
    VALUES (
        @LeaveType + ' Rules',
        'Leave rules configuration for ' + @LeaveType,
        'MaxDuration=' + CAST(@MaxDuration AS VARCHAR(10)) + ';WorkflowType=' + @WorkflowType,
        @NoticePeriod,
        @LeaveType,
        1
    );

    SELECT 'Leave rules configured successfully' AS ConfirmationMessage;
END;
GO
--33. ConfigureSpecialLeave
CREATE PROCEDURE ConfigureSpecialLeave
    @LeaveType VARCHAR(50),
    @Rules VARCHAR(200)
AS
BEGIN
    INSERT INTO LeavePolicy (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year)
    VALUES (
        @LeaveType + ' Policy',
        'Special leave policy for ' + @LeaveType,
        @Rules,
        0,
        @LeaveType,
        0
    );

    SELECT 'Special leave configured successfully' AS ConfirmationMessage;
END;
GO

--34 SetLeaveYearRules
CREATE PROCEDURE SetLeaveYearRules
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    INSERT INTO LeavePolicy (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year)
    VALUES (
        'Leave Year Configuration',
        'Defines the legal leave year period and reset rules',
        'StartDate=' + CAST(@StartDate AS VARCHAR(20)) + ';EndDate=' + CAST(@EndDate AS VARCHAR(20)),
        0,
        'Annual Reset',
        1
    );

    SELECT 'Leave year rules set successfully' AS ConfirmationMessage;
END;
GO

--35 AdjustLeaveBalance
CREATE PROCEDURE AdjustLeaveBalance
    @EmployeeID INT,
    @LeaveType VARCHAR(50),
    @Adjustment DECIMAL(5,2)
AS
BEGIN
    DECLARE @LeaveTypeID INT;
    
    SELECT @LeaveTypeID = leave_id
    FROM Leave
    WHERE leave_type = @LeaveType;
    
    UPDATE LeaveEntitlement
    SET entitlement = entitlement + @Adjustment
    WHERE employee_id = @EmployeeID
    AND leave_type_id = @LeaveTypeID;

    SELECT 'Leave balance adjusted successfully' AS ConfirmationMessage;
END;
GO


--36 ManageLeaveRoles
CREATE PROCEDURE ManageLeaveRoles
    @RoleID INT,
    @Permissions VARCHAR(200)
AS
BEGIN
    INSERT INTO RolePermission (role_id, permission_name, allowed_action)
    VALUES (
        @RoleID,
        'Leave Management',
        @Permissions
    );

    SELECT 'Leave role permissions managed successfully' AS ConfirmationMessage;
END;
GO
--37 FinalizeLeaveRequest
CREATE PROCEDURE FinalizeLeaveRequest
    @LeaveRequestID INT
AS
BEGIN
    DECLARE @EmployeeID INT;
    DECLARE @LeaveTypeID INT;
    DECLARE @Duration DECIMAL(5,2);
    
    SELECT 
        @EmployeeID = employee_id,
        @LeaveTypeID = leave_id,
        @Duration = duration
    FROM LeaveRequest
    WHERE request_id = @LeaveRequestID;
    
    UPDATE LeaveRequest
    SET status = 'Finalized'
    WHERE request_id = @LeaveRequestID;
    
    UPDATE LeaveEntitlement
    SET entitlement = entitlement - @Duration
    WHERE employee_id = @EmployeeID
    AND leave_type_id = @LeaveTypeID;

    SELECT 'Leave request finalized successfully' AS ConfirmationMessage;
END;
GO
--38 OverrideLeaveDecision
CREATE PROCEDURE OverrideLeaveDecision
    @LeaveRequestID INT,
    @Reason VARCHAR(200)
AS
BEGIN
    DECLARE @CurrentStatus VARCHAR(50);
    
    SELECT @CurrentStatus = status
    FROM LeaveRequest
    WHERE request_id = @LeaveRequestID;
    
    IF @CurrentStatus = 'Rejected'
    BEGIN
        UPDATE LeaveRequest
        SET status = 'Approved - Override',
            justification = justification + ' | Override Reason: ' + @Reason
        WHERE request_id = @LeaveRequestID;
    END
    ELSE IF @CurrentStatus = 'Approved'
    BEGIN
        UPDATE LeaveRequest
        SET status = 'Rejected - Override',
            justification = justification + ' | Override Reason: ' + @Reason
        WHERE request_id = @LeaveRequestID;
    END;

    SELECT 'Leave decision overridden successfully' AS ConfirmationMessage;
END;
GO
--39 BulkProcessLeaveRequests
CREATE PROCEDURE BulkProcessLeaveRequests
    @LeaveRequestIDs VARCHAR(500)
AS
BEGIN
    UPDATE LeaveRequest
    SET status = 'Approved'
    WHERE request_id IN (SELECT value FROM STRING_SPLIT(@LeaveRequestIDs, ','));

    SELECT 'Leave requests processed successfully' AS ConfirmationMessage;
END;
GO
-- 40. VerifyMedicalLeave
CREATE PROCEDURE VerifyMedicalLeave
    @LeaveRequestID INT,
    @DocumentID INT
AS
BEGIN
    UPDATE LeaveDocument
    SET file_path = file_path + ' | Verified'
    WHERE document_id = @DocumentID
    AND leave_request_id = @LeaveRequestID;
    
    UPDATE LeaveRequest
    SET status = 'Approved - Document Verified'
    WHERE request_id = @LeaveRequestID;

    SELECT 'Medical leave document verified successfully' AS ConfirmationMessage;
END;
GO
--41 SyncLeaveBalances
CREATE PROCEDURE SyncLeaveBalances
    @LeaveRequestID INT
AS
BEGIN
    DECLARE @EmployeeID INT;
    DECLARE @LeaveTypeID INT;
    DECLARE @Duration DECIMAL(5,2);
    
    SELECT 
        @EmployeeID = employee_id,
        @LeaveTypeID = leave_id,
        @Duration = duration
    FROM LeaveRequest
    WHERE request_id = @LeaveRequestID;
    
    UPDATE LeaveEntitlement
    SET entitlement = entitlement - @Duration
    WHERE employee_id = @EmployeeID
    AND leave_type_id = @LeaveTypeID;
    
    UPDATE LeaveRequest
    SET status = 'Approved - Balance Updated'
    WHERE request_id = @LeaveRequestID;

    SELECT 'Leave balances synced successfully' AS ConfirmationMessage;
END;
GO
--42 ProcessLeaveCarryForward
CREATE PROCEDURE ProcessLeaveCarryForward
    @Year INT
AS
BEGIN
    UPDATE le
    SET le.entitlement = 
        CASE 
            -- If leave policy says reset on new year = 0 (don't reset), keep full balance
            WHEN lp.reset_on_new_year = 0 THEN le.entitlement
            
            -- If it's vacation leave with carry-over rules, apply carry-over limit
            WHEN vl.carry_over_days IS NOT NULL AND le.entitlement > vl.carry_over_days 
            THEN vl.carry_over_days
            
            -- If it's vacation leave with carry-over and balance is less than limit, keep it
            WHEN vl.carry_over_days IS NOT NULL 
            THEN le.entitlement
            
            -- If leave policy says reset on new year = 1, reset to 0
            WHEN lp.reset_on_new_year = 1 THEN 0
            
            -- Default: keep current balance
            ELSE le.entitlement
        END
    FROM LeaveEntitlement le
    INNER JOIN Leave l ON le.leave_type_id = l.leave_id
    LEFT JOIN VacationLeave vl ON l.leave_id = vl.leave_id
    LEFT JOIN LeavePolicy lp ON l.leave_type = lp.special_leave_type;

    SELECT 'Leave carry-forward processed for year ' + CAST(@Year AS VARCHAR(10)) + ' successfully' AS ConfirmationMessage;
END;
GO
--43 SyncLeaveToAttendance
CREATE PROCEDURE SyncLeaveToAttendance
    @LeaveRequestID INT
AS
BEGIN
    DECLARE @EmployeeID INT;
    DECLARE @LeaveType VARCHAR(50);
    DECLARE @Duration INT;
    
    SELECT 
        @EmployeeID = lr.employee_id,
        @LeaveType = l.leave_type,
        @Duration = lr.duration
    FROM LeaveRequest lr
    INNER JOIN Leave l ON lr.leave_id = l.leave_id
    WHERE lr.request_id = @LeaveRequestID;
    
    INSERT INTO Exception (name, category, date, status)
    VALUES (
        @LeaveType + ' Leave',
        'Leave',
        GETDATE(),
        'Active'
    );
    
    INSERT INTO Employee_Exception (employee_id, exception_id)
    VALUES (
        @EmployeeID,
        SCOPE_IDENTITY()
    );

    SELECT 'Leave synced to attendance successfully' AS ConfirmationMessage;
END;
GO
--44 UpdateInsuranceBrackets
CREATE PROCEDURE UpdateInsuranceBrackets
    @BracketID INT,
    @NewMinSalary DECIMAL(10,2),
    @NewMaxSalary DECIMAL(10,2),
    @NewEmployeeContribution DECIMAL(5,2),
    @NewEmployerContribution DECIMAL(5,2),
    @UpdatedBy INT
AS
BEGIN
    DECLARE @InsuranceType VARCHAR(50);
    
    SELECT @InsuranceType = type
    FROM Insurance
    WHERE insurance_id = @BracketID;
    
    UPDATE Insurance
    SET contribution_rate = @NewEmployeeContribution,
        coverage = 'MinSalary=' + CAST(@NewMinSalary AS VARCHAR(20)) + 
                   ';MaxSalary=' + CAST(@NewMaxSalary AS VARCHAR(20)) + 
                   ';EmployerContribution=' + CAST(@NewEmployerContribution AS VARCHAR(20))
    WHERE insurance_id = @BracketID;
    
    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES (
        'Insurance bracket ID ' + CAST(@BracketID AS VARCHAR(10)) + 
        ' (' + @InsuranceType + ') updated by Employee ID ' + CAST(@UpdatedBy AS VARCHAR(10)) + 
        '. New salary range: ' + CAST(@NewMinSalary AS VARCHAR(20)) + ' - ' + CAST(@NewMaxSalary AS VARCHAR(20)) + 
        '. Employee contribution: ' + CAST(@NewEmployeeContribution AS VARCHAR(20)) + 
        '%, Employer contribution: ' + CAST(@NewEmployerContribution AS VARCHAR(20)) + '%',
        'Medium',
        'Insurance Update'
    );
    
    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    VALUES (
        @UpdatedBy,
        SCOPE_IDENTITY(),
        'Delivered',
        GETDATE()
    );

    SELECT 'Insurance bracket updated successfully' AS ConfirmationMessage;
END;
GO
--45 ApprovePolicyUpdate
CREATE OR ALTER PROCEDURE ApprovePolicyUpdate
    @PolicyID INT,
    @ApprovedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE PayrollPolicy
    SET description = description + ' | Approved by ' + CAST(@ApprovedBy AS VARCHAR)
    WHERE policy_id = @PolicyID;

    PRINT 'Policy update approved.';
END;
GO
 
