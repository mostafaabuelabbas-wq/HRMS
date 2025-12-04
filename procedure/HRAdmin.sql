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


-- 11. CreateEmployeeProfile
CREATE PROCEDURE CreateEmployeeProfile
    @FirstName VARCHAR(50),
    @LastName VARCHAR(50),
    @DepartmentID INT,
    @RoleID INT,     -- maps to position_id in schema
    @HireDate DATE,
    @Email VARCHAR(100),
    @Phone VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Employee (
        first_name,
        last_name,
        email,
        phone,
        department_id,
        position_id,
        hire_date,
        is_active,
        profile_completion
    )
    VALUES (
        @FirstName,
        @LastName,
        @Email,
        @Phone,
        @DepartmentID,
        @RoleID,
        @HireDate,
        1,
        0
    );

    SELECT 
        SCOPE_IDENTITY() AS EmployeeID,
        'Employee profile created successfully.' AS Message;
END;
GO


-- 12. UpdateEmployeeProfile**
CREATE PROCEDURE UpdateEmployeeProfile
    @EmployeeID INT,
    @FieldName VARCHAR(50),
    @NewValue VARCHAR(255)
AS
BEGIN
    IF @FieldName = 'first_name'
        UPDATE Employee SET first_name = @NewValue WHERE employee_id = @EmployeeID;
    ELSE IF @FieldName = 'last_name'
        UPDATE Employee SET last_name = @NewValue WHERE employee_id = @EmployeeID;
    ELSE IF @FieldName = 'email'
        UPDATE Employee SET email = @NewValue WHERE employee_id = @EmployeeID;
    ELSE IF @FieldName = 'phone'
        UPDATE Employee SET phone = @NewValue WHERE employee_id = @EmployeeID;
    ELSE IF @FieldName = 'address'
        UPDATE Employee SET address = @NewValue WHERE employee_id = @EmployeeID;
    ELSE IF @FieldName = 'emergency_contact_name'
        UPDATE Employee SET emergency_contact_name = @NewValue WHERE employee_id = @EmployeeID;
    ELSE IF @FieldName = 'emergency_contact_phone'
        UPDATE Employee SET emergency_contact_phone = @NewValue WHERE employee_id = @EmployeeID;
    ELSE IF @FieldName = 'biography'
        UPDATE Employee SET biography = @NewValue WHERE employee_id = @EmployeeID;
    ELSE IF @FieldName = 'employment_status'
        UPDATE Employee SET employment_status = @NewValue WHERE employee_id = @EmployeeID;
    ELSE IF @FieldName = 'account_status'
        UPDATE Employee SET account_status = @NewValue WHERE employee_id = @EmployeeID;
    ELSE
    BEGIN
        SELECT 'Error: Invalid field name' AS ConfirmationMessage;
        RETURN;
    END

    SELECT 'Employee profile updated successfully' AS ConfirmationMessage;
END;
GO


-- 13. SetProfileCompleteness
CREATE PROCEDURE [SetProfileCompleteness]
    @EmployeeID INT,
    @CompletenessPercentage INT
AS
BEGIN
UPDATE Employee
SET profile_completion = @CompletenessPercentage
WHERE employee_id = @EmployeeID;

SELECT 
        'Profile completeness updated to ' + CAST(@CompletenessPercentage AS VARCHAR(10)) + '%' AS ConfirmationMessage,
        @CompletenessPercentage AS UpdatedCompleteness;
END;

GO

-- 14. GenerateProfileReport
CREATE PROCEDURE GenerateProfileReport
    @FilterField VARCHAR(50),
    @FilterValue VARCHAR(100)
AS
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
    LEFT JOIN Position p ON e.position_id = p.position_id
    WHERE 
        (@FilterField = 'department' AND d.department_name = @FilterValue)
        OR (@FilterField = 'employment_status' AND e.employment_status = @FilterValue)
        OR (@FilterField = 'country_of_birth' AND e.country_of_birth = @FilterValue)
        OR (@FilterField = 'all');
END;
GO

-- 15. CreateShiftType
CREATE PROCEDURE CreateShiftType
    @ShiftTypeName VARCHAR(50),
    @Description VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO ShiftType (name, description)
    VALUES (@ShiftTypeName, @Description);

    SELECT 'Shift type created successfully.' AS Message;
END;
GO


-- 17. AssignRotationalShift
CREATE PROCEDURE AssignRotationalShift
    @EmployeeID INT,
    @ShiftCycle INT,
    @StartDate DATE,
    @EndDate DATE,
    @Status VARCHAR(20)
AS
BEGIN
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

    SELECT 'Rotational shift assigned successfully to employee ' + CAST(@EmployeeID AS VARCHAR(10)) AS ConfirmationMessage;
END;
GO

-- 18. NotifyShiftExpiry
CREATE PROCEDURE NotifyShiftExpiry
    @EmployeeID INT,
    @ShiftAssignmentID INT,
    @ExpiryDate DATE
AS
BEGIN
    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES (
        'Your shift assignment ID ' + CAST(@ShiftAssignmentID AS VARCHAR(50)) + 
        ' is expiring on ' + CAST(@ExpiryDate AS VARCHAR(50)),
        'High',
        'Shift Expiry'
    );

    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    VALUES (
        @EmployeeID,
        SCOPE_IDENTITY(),
        'Pending',
        GETDATE()
    );

    SELECT 'Shift expiry notification sent successfully' AS ConfirmationMessage;
END;
GO
-- 19. DefineShortTimeRules
CREATE PROCEDURE DefineShortTimeRules
    @RuleName VARCHAR(50),
    @LateMinutes INT,
    @EarlyLeaveMinutes INT,
    @PenaltyType VARCHAR(50)
AS
BEGIN
    INSERT INTO PayrollPolicy (effective_date, type, description)
    VALUES (
        GETDATE(),
        'Short Time',
        @RuleName + ' - Late arrival penalty after ' + CAST(@LateMinutes AS VARCHAR(10)) + 
        ' mins, Early leave penalty after ' + CAST(@EarlyLeaveMinutes AS VARCHAR(10)) + 
        ' mins. Penalty type: ' + @PenaltyType
    );

    SELECT 'Short time rule defined successfully' AS ConfirmationMessage;
END;
GO

--20. SetGracePeriod
CREATE PROCEDURE SetGracePeriod
    @Minutes INT
AS
BEGIN
    INSERT INTO PayrollPolicy (effective_date, type, description)
    VALUES (
        GETDATE(),
        'Lateness',
        'Grace period: First ' + CAST(@Minutes AS VARCHAR(10)) + ' minutes of lateness tolerated'
    );

    INSERT INTO LatenessPolicy (policy_id, grace_period_mins, deduction_rate)
    VALUES (
        SCOPE_IDENTITY(),
        @Minutes,
        0.00
    );

    SELECT 'Grace period set successfully' AS ConfirmationMessage;
END;
GO
--21) DefinePenaltyThreshold 
CREATE PROCEDURE DefinePenaltyThreshold
    @LateMinutes INT,
    @DeductionType VARCHAR(50)
AS
BEGIN
    INSERT INTO PayrollPolicy (effective_date, type, description)
    VALUES (
        GETDATE(),
        'Lateness Penalty',
        'Penalty threshold: Lateness over ' + CAST(@LateMinutes AS VARCHAR(10)) + ' minutes'
    );

    INSERT INTO DeductionPolicy (policy_id, deduction_reason, calculation_mode)
    VALUES (
        SCOPE_IDENTITY(),
        @DeductionType,
        'LateMinutes=' + CAST(@LateMinutes AS VARCHAR(10))
    );

    SELECT 'Penalty threshold defined successfully' AS ConfirmationMessage;
END;
GO

--22) DefinePermissionLimits************************************************************************************
CREATE PROCEDURE DefinePermissionLimits
    @MinHours INT,
    @MaxHours INT
AS
BEGIN
    INSERT INTO PayrollPolicy (effective_date, type, description)
    VALUES (
        GETDATE(),
        'PermissionLimits',
        'MinHours=' + CAST(@MinHours AS VARCHAR(10)) + ';MaxHours=' + CAST(@MaxHours AS VARCHAR(10))
    );

    SELECT 'Permission limits defined successfully' AS ConfirmationMessage;
END;
GO
--*************************************************************************************************************
--23) EscalatePendingRequests
CREATE PROCEDURE EscalatePendingRequests
    @Deadline DATETIME
AS
BEGIN
    -- Escalate LeaveRequests
    UPDATE LeaveRequest
    SET status = 'Escalated'
    WHERE status = 'Pending'
    AND (approval_timing IS NULL OR approval_timing < @Deadline);
    
    -- Escalate AttendanceCorrectionRequests
    UPDATE AttendanceCorrectionRequest
    SET status = 'Escalated'
    WHERE status = 'Pending'
    AND date < @Deadline;
    
    -- Escalate Reimbursements
    UPDATE Reimbursement
    SET current_status = 'Escalated'
    WHERE current_status = 'Pending'
    AND (approval_date IS NULL OR approval_date < @Deadline);
    
    SELECT 'Pending requests escalated successfully' AS ConfirmationMessage;
END;
GO

--24) LinkVacationToShift
CREATE PROCEDURE LinkVacationToShift
    @VacationPackageID INT,
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LeaveTypeID INT;

    SELECT TOP 1 @LeaveTypeID = leave_id
    FROM [Leave]
    WHERE leave_type LIKE '%Vacation%';

    IF EXISTS (
        SELECT 1 FROM LeaveEntitlement
        WHERE employee_id = @EmployeeID
        AND leave_type_id = @LeaveTypeID
    )
    BEGIN
        SELECT 'Vacation already linked.' AS Message;
        RETURN;
    END

    INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
    VALUES (@EmployeeID, @LeaveTypeID, 0);

    SELECT 'Vacation linked successfully.' AS Message;
END;
GO


--25) ConfigureLeavePolicies
CREATE PROCEDURE ConfigureLeavePolicies
AS
BEGIN
    INSERT INTO LeavePolicy (name, purpose, eligibility_rules, notice_period, special_leave_type, reset_on_new_year)
    VALUES (
        'Default Leave Policy',
        'Standard leave configuration',
        'All employees eligible',
        7,
        'Standard',
        1
    );

    SELECT 'Leave policies configured successfully' AS ConfirmationMessage;
END;
GO


--26) AuthenticateLeaveAdmin
CREATE PROCEDURE AuthenticateLeaveAdmin
    @AdminID INT,
    @Password VARCHAR(100)
AS
BEGIN
    SELECT 
        e.employee_id,
        e.full_name,
        hr.approval_level,
        r.role_name
    FROM Employee e
    INNER JOIN HRAdministrator hr ON e.employee_id = hr.employee_id
    INNER JOIN Employee_Role er ON e.employee_id = er.employee_id
    INNER JOIN Role r ON er.role_id = r.role_id
    WHERE e.employee_id = @AdminID;

    SELECT 'Administrator authenticated successfully' AS ConfirmationMessage;
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
--28. UpdateLeaveEntitlements
CREATE PROCEDURE UpdateLeaveEntitlements
    @EmployeeID INT
AS
BEGIN
    -- Delete existing entitlements for this employee
    DELETE FROM LeaveEntitlement
    WHERE employee_id = @EmployeeID;

    -- Get employee contract type
    DECLARE @ContractID INT;
    DECLARE @ContractType VARCHAR(50);
    
    SELECT @ContractID = contract_id
    FROM Employee
    WHERE employee_id = @EmployeeID;
    
    SELECT @ContractType = type
    FROM Contract
    WHERE contract_id = @ContractID;

    -- Apply vacation leave based on contract type
    IF @ContractType = 'Full-Time'
    BEGIN
        INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
        SELECT @EmployeeID, leave_id, 21.00
        FROM VacationLeave;
    END
    ELSE IF @ContractType = 'Part-Time'
    BEGIN
        INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
        SELECT @EmployeeID, leave_id, 10.00
        FROM VacationLeave;
    END;

    -- Apply sick leave based on contract type
    IF @ContractType = 'Full-Time' OR @ContractType = 'Part-Time'
    BEGIN
        INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
        SELECT @EmployeeID, leave_id, 10.00
        FROM SickLeave;
    END;

    -- Apply probation leave for new employees
    IF EXISTS (
        SELECT 1 FROM Employee 
        WHERE employee_id = @EmployeeID 
        AND DATEDIFF(MONTH, hire_date, GETDATE()) <= 6
    )
    BEGIN
        INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
        SELECT @EmployeeID, leave_id, 5.00
        FROM ProbationLeave;
    END;

    -- Apply holiday leave for all
    INSERT INTO LeaveEntitlement (employee_id, leave_type_id, entitlement)
    SELECT @EmployeeID, leave_id, 0.00
    FROM HolidayLeave;

    SELECT 'Leave entitlements updated successfully' AS ConfirmationMessage;
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
--30 ManageLeaveTypes
CREATE PROCEDURE ManageLeaveTypes
    @LeaveType VARCHAR(50),
    @Description VARCHAR(200)
AS
BEGIN
    INSERT INTO Leave (leave_type, leave_description)
    VALUES (
        @LeaveType,
        @Description
    );

    SELECT 'Leave type managed successfully' AS ConfirmationMessage;
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
 
