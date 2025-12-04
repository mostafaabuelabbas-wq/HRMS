
 --Employee
--1 SubmitLeaveRequest
CREATE PROCEDURE SubmitLeaveRequest
    @EmployeeID INT,
    @LeaveTypeID INT,
    @StartDate DATE,
    @EndDate DATE,
    @Reason VARCHAR(100)
AS
BEGIN
    DECLARE @Duration INT;
    DECLARE @Entitlement DECIMAL(5,2);
    DECLARE @ManagerID INT;
    DECLARE @EmployeeName VARCHAR(101);
    DECLARE @LeaveType VARCHAR(50);
    
    -- Step 1: Validate Employee
    SELECT @EmployeeName = full_name, @ManagerID = manager_id
    FROM Employee
    WHERE employee_id = @EmployeeID;
    
    IF @EmployeeName IS NULL
    BEGIN
        SELECT 'Invalid employee' AS ConfirmationMessage;
        RETURN;
    END;
    
    -- Step 2: Validate Leave Type
    SELECT @LeaveType = leave_type
    FROM Leave
    WHERE leave_id = @LeaveTypeID;
    
    IF @LeaveType IS NULL
    BEGIN
        SELECT 'Invalid leave type' AS ConfirmationMessage;
        RETURN;
    END;
    
    -- Step 3: Calculate Duration
    SET @Duration = DATEDIFF(DAY, @StartDate, @EndDate) + 1;
    
    IF @Duration <= 0
    BEGIN
        SELECT 'Invalid date range' AS ConfirmationMessage;
        RETURN;
    END;
    
    -- Step 4: Validate Against Entitlement
    SELECT @Entitlement = entitlement
    FROM LeaveEntitlement
    WHERE employee_id = @EmployeeID AND leave_type_id = @LeaveTypeID;
    
    IF @Entitlement IS NULL
    BEGIN
        SELECT 'No leave entitlement found for this leave type' AS ConfirmationMessage;
        RETURN;
    END;
    
    IF @Duration > @Entitlement
    BEGIN
        SELECT 'Insufficient leave balance. Requested: ' + CAST(@Duration AS VARCHAR(10)) + 
               ' days, Available: ' + CAST(@Entitlement AS VARCHAR(10)) + ' days' AS ConfirmationMessage;
        RETURN;
    END;
    
    -- Step 5: Insert Into LeaveRequest
    INSERT INTO LeaveRequest (employee_id, leave_id, justification, duration, approval_timing, status)
    VALUES (
        @EmployeeID,
        @LeaveTypeID,
        @Reason,
        @Duration,
        NULL,
        'Pending'
    );
    
    -- Step 6: Notify Manager
    IF @ManagerID IS NOT NULL
    BEGIN
        INSERT INTO Notification (message_content, urgency, notification_type)
        VALUES (
            'New leave request submitted by ' + @EmployeeName + ' (Employee ID: ' + CAST(@EmployeeID AS VARCHAR(10)) + 
            ') for ' + CAST(@Duration AS VARCHAR(10)) + ' days of ' + @LeaveType + 
            ' from ' + CAST(@StartDate AS VARCHAR(20)) + ' to ' + CAST(@EndDate AS VARCHAR(20)),
            'Normal',
            'Leave Request'
        );
        
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (
            @ManagerID,
            SCOPE_IDENTITY(),
            'Pending',
            GETDATE()
        );
    END;
    
    -- Step 7: Return Confirmation Message
    SELECT 'Leave request submitted successfully' AS ConfirmationMessage;
END;
GO
-- 2 GetLeaveBalance
CREATE PROCEDURE GetLeaveBalance
    @EmployeeID INT
AS
BEGIN
    SELECT 
        e.employee_id,
        e.full_name,
        l.leave_type,
        le.entitlement AS remaining_days
    FROM Employee e
    INNER JOIN LeaveEntitlement le ON e.employee_id = le.employee_id
    INNER JOIN Leave l ON le.leave_type_id = l.leave_id
    WHERE e.employee_id = @EmployeeID;
END;
GO
-- 3 RecordAttendance
CREATE PROCEDURE RecordAttendance
    @EmployeeID INT,
    @ShiftID INT,
    @EntryTime TIME,
    @ExitTime TIME
AS
BEGIN
    DECLARE @EntryDateTime DATETIME;
    DECLARE @ExitDateTime DATETIME;
    
    SET @EntryDateTime = CAST(CAST(GETDATE() AS DATE) AS DATETIME) + CAST(@EntryTime AS DATETIME);
    SET @ExitDateTime = CAST(CAST(GETDATE() AS DATE) AS DATETIME) + CAST(@ExitTime AS DATETIME);
    
    INSERT INTO Attendance (employee_id, shift_id, entry_time, exit_time, login_method, logout_method, exception_id)
    VALUES (
        @EmployeeID,
        @ShiftID,
        @EntryDateTime,
        @ExitDateTime,
        'Manual',
        'Manual',
        NULL
    );

    SELECT 'Attendance recorded successfully' AS ConfirmationMessage;
END;
GO
-- 4 SubmitReimbursement
CREATE PROCEDURE SubmitReimbursement
    @EmployeeID INT,
    @ExpenseType VARCHAR(50),
    @Amount DECIMAL(10,2)
AS
BEGIN
    DECLARE @EmployeeName VARCHAR(101);
    DECLARE @ManagerID INT;
    
    -- Step 1: Validate Employee
    SELECT @EmployeeName = full_name, @ManagerID = manager_id
    FROM Employee
    WHERE employee_id = @EmployeeID;
    
    IF @EmployeeName IS NULL
    BEGIN
        SELECT 'Invalid employee' AS ConfirmationMessage;
        RETURN;
    END;
    
    -- Step 2: Insert Reimbursement Record
    INSERT INTO Reimbursement (type, claim_type, approval_date, current_status, employee_id)
    VALUES (
        @ExpenseType,
        'Amount=' + CAST(@Amount AS VARCHAR(20)),
        NULL,
        'Pending',
        @EmployeeID
    );
    
    -- Step 3: Notify Manager (optional but recommended)
    IF @ManagerID IS NOT NULL
    BEGIN
        INSERT INTO Notification (message_content, urgency, notification_type)
        VALUES (
            'New reimbursement request submitted by ' + @EmployeeName + 
            ' (Employee ID: ' + CAST(@EmployeeID AS VARCHAR(10)) + 
            ') for ' + @ExpenseType + ' - Amount: ' + CAST(@Amount AS VARCHAR(20)),
            'Normal',
            'Reimbursement Request'
        );
        
        INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
        VALUES (
            @ManagerID,
            SCOPE_IDENTITY(),
            'Pending',
            GETDATE()
        );
    END;
    
    -- Step 4: Return Confirmation Message
    SELECT 'Reimbursement request submitted successfully' AS ConfirmationMessage;
END;
GO
--5 AddEmployeeSkill
CREATE PROCEDURE AddEmployeeSkill
    @EmployeeID INT,
    @SkillName VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SkillID INT;

    SELECT @SkillID = skill_id FROM Skill WHERE skill_name = @SkillName;

    IF @SkillID IS NULL
    BEGIN
        INSERT INTO Skill (skill_name) VALUES (@SkillName);
        SET @SkillID = SCOPE_IDENTITY();
    END

    IF EXISTS (
        SELECT 1 FROM Employee_Skill
        WHERE employee_id = @EmployeeID AND skill_id = @SkillID
    )
    BEGIN
        SELECT 'Skill already exists.' AS Message;
        RETURN;
    END

    INSERT INTO Employee_Skill (employee_id, skill_id, proficiency_level)
    VALUES (@EmployeeID, @SkillID, 1);

    SELECT 'Skill added.' AS Message;
END;
GO

--6 ViewAssignedShifts
CREATE PROCEDURE ViewAssignedShifts
    @EmployeeID INT
AS
BEGIN
    SELECT 
        sa.assignment_id,
        sa.start_date,
        sa.end_date,
        sa.status AS assignment_status,
        ss.shift_id,
        ss.name AS shift_name,
        ss.type AS shift_type,
        ss.start_time,
        ss.end_time,
        ss.break_duration,
        ss.shift_date,
        ss.status AS shift_status
    FROM ShiftAssignment sa
    INNER JOIN ShiftSchedule ss ON sa.shift_id = ss.shift_id
    WHERE sa.employee_id = @EmployeeID
    ORDER BY sa.start_date DESC, ss.start_time;
END;
GO

--7 ViewMyContracts
CREATE PROCEDURE ViewMyContracts
    @EmployeeID INT
AS
BEGIN
    DECLARE @EmployeeName VARCHAR(101);
    DECLARE @ContractID INT;
    
    -- Step 1: Validate Employee
    SELECT @EmployeeName = full_name, @ContractID = contract_id
    FROM Employee
    WHERE employee_id = @EmployeeID;
    
    IF @EmployeeName IS NULL
    BEGIN
        SELECT 'Invalid employee' AS Message;
        RETURN;
    END;
    
    -- Step 2 & 3: Get employee's current contract
    SELECT 
        c.contract_id,
        c.type AS contract_type,
        c.start_date,
        c.end_date,
        c.current_state,
        -- Full-time contract details
        ftc.leave_entitlement,
        ftc.insurance_eligibility,
        ftc.weekly_working_hours,
        -- Part-time contract details
        ptc.working_hours AS part_time_hours,
        ptc.hourly_rate,
        -- Consultant contract details
        cc.project_scope,
        cc.fees,
        cc.payment_schedule,
        -- Internship contract details
        ic.mentoring,
        ic.evaluation,
        ic.stipend_related
    FROM Contract c
    LEFT JOIN FullTimeContract ftc ON c.contract_id = ftc.contract_id
    LEFT JOIN PartTimeContract ptc ON c.contract_id = ptc.contract_id
    LEFT JOIN ConsultantContract cc ON c.contract_id = cc.contract_id
    LEFT JOIN InternshipContract ic ON c.contract_id = ic.contract_id
    WHERE c.contract_id = @ContractID
    ORDER BY c.start_date DESC;
END;
GO


-- 8. ViewMyPayroll
CREATE PROCEDURE ViewMyPayroll
    @EmployeeID INT
AS

BEGIN
    SELECT *
    FROM Payroll
    WHERE employee_id = @EmployeeID;
END;
GO


-- 9. UpdatePersonalDetails
CREATE PROCEDURE UpdatePersonalDetails
    @EmployeeID INT,
    @Phone VARCHAR(20),
    @Address VARCHAR(150)
AS
BEGIN
    UPDATE Employee
    SET phone = @Phone,
        address = @Address
    WHERE employee_id = @EmployeeID;
    
    SELECT 'Personal details updated successfully' AS ConfirmationMessage;
END;
GO


-- 10. ViewMyMissions
CREATE PROCEDURE ViewMyMissions
    @EmployeeID INT
AS
BEGIN
    SELECT *
    FROM Mission
    WHERE employee_id = @EmployeeID;
END;
GO


-- 11. ViewEmployeeProfile
CREATE PROCEDURE ViewEmployeeProfile
    @EmployeeID INT
AS
BEGIN
    SELECT 
        e.*,
        d.department_name,
        p.position_title,
        c.type AS contract_type,
        st.type AS salary_type
    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    LEFT JOIN Contract c ON e.contract_id = c.contract_id
    LEFT JOIN SalaryType st ON e.salary_type_id = st.salary_type_id
    WHERE e.employee_id = @EmployeeID;
END;
GO


-- 12. UpdateContactInformation
CREATE PROCEDURE UpdateContactInformation
    @EmployeeID INT,
    @RequestType VARCHAR(50),
    @NewValue VARCHAR(100)
AS
BEGIN
    UPDATE Employee
    SET phone = CASE WHEN @RequestType = 'Phone' THEN @NewValue ELSE phone END,
        address = CASE WHEN @RequestType = 'Address' THEN @NewValue ELSE address END
    WHERE employee_id = @EmployeeID;
    
    SELECT 'Contact information updated successfully' AS ConfirmationMessage;
END;
GO


-- 13. ViewEmploymentTimeline
CREATE PROCEDURE ViewEmploymentTimeline
    @EmployeeID INT
AS
BEGIN
    SELECT 
        e.employee_id,
        e.full_name,
        e.hire_date,
        d.department_name,
        p.position_title,
        e.employment_status
    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    WHERE e.employee_id = @EmployeeID;
END;
GO


-- 14. UpdateEmergencyContact
CREATE PROCEDURE UpdateEmergencyContact
    @EmployeeID INT,
    @ContactName VARCHAR(100),
    @Relation VARCHAR(50),
    @Phone VARCHAR(20)
AS
BEGIN
    UPDATE Employee
    SET emergency_contact_name = @ContactName,
        relationship = @Relation,
        emergency_contact_phone = @Phone
    WHERE employee_id = @EmployeeID;
    
    SELECT 'Emergency contact updated successfully' AS ConfirmationMessage;
END;
GO


-- 15. RequestHRDocument
CREATE PROCEDURE RequestHRDocument
    @EmployeeID INT,
    @DocumentType VARCHAR(50)
AS
BEGIN
    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES ('HR Document Request: Employee ID ' + CAST(@EmployeeID AS VARCHAR) + 
            ' has requested a ' + @DocumentType + ' document.', 
            'Medium', 
            'HR Document Request');
    
    SELECT 'HR document request submitted successfully' AS ConfirmationMessage;
END;
GO


-- 16. NotifyProfileUpdate
CREATE PROCEDURE NotifyProfileUpdate
    @EmployeeID INT,
    @ChangeType VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1) Insert notification
    INSERT INTO Notification (message_content, timestamp, urgency, read_status, notification_type)
    VALUES (
        CONCAT('Profile update: ', @ChangeType),
        GETDATE(),
        'Normal',
        0,
        'ProfileUpdate'
    );

    DECLARE @NotificationID INT = SCOPE_IDENTITY();

    -- 2) Link notification to employee
    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status, delivered_at)
    VALUES (@EmployeeID, @NotificationID, 'Delivered', GETDATE());

    SELECT 'Notification sent successfully.' AS Message;
END;
GO

-- 17. LogFlexibleAttendance
CREATE PROCEDURE LogFlexibleAttendance
    @EmployeeID INT,
    @Date DATE,
    @CheckIn TIME,
    @CheckOut TIME
AS
BEGIN
    INSERT INTO Attendance (employee_id, entry_time, exit_time, login_method, logout_method)
    VALUES (
        @EmployeeID,
        CAST(@Date AS DATETIME) + CAST(@CheckIn AS DATETIME),
        CAST(@Date AS DATETIME) + CAST(@CheckOut AS DATETIME),
        'Flexible',
        'Flexible'
    );

    SELECT 
        'Attendance logged successfully' AS Message,
        DATEDIFF(MINUTE, 
            CAST(@Date AS DATETIME) + CAST(@CheckIn AS DATETIME),
            CAST(@Date AS DATETIME) + CAST(@CheckOut AS DATETIME)
        ) / 60.0 AS TotalHours;
END;
GO
 
 --18. NotifyMissedPunch
 CREATE PROCEDURE NotifyMissedPunch
    @EmployeeID INT,
    @Date DATE
AS
BEGIN
    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES (
        'You have a missed punch on ' + CONVERT(VARCHAR, @Date, 23) + '. Please submit an attendance correction request.',
        'High',
        'MissedPunch'
    );

    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status)
    VALUES (
        @EmployeeID,
        SCOPE_IDENTITY(),
        'Pending'
    );

    SELECT 'Notification sent for missed punch on ' + CONVERT(VARCHAR, @Date, 23) AS Message;
END;
GO

-- 19. RecordMultiplePunches
CREATE PROCEDURE RecordMultiplePunches
    @EmployeeID INT,
    @ClockInOutTime DATETIME,
    @Type VARCHAR(10)
AS
BEGIN
    UPDATE Attendance
    SET exit_time = @ClockInOutTime,
        logout_method = @Type
    WHERE employee_id = @EmployeeID 
        AND exit_time IS NULL
        AND CAST(entry_time AS DATE) = CAST(@ClockInOutTime AS DATE);

    INSERT INTO Attendance (employee_id, entry_time, login_method)
    SELECT @EmployeeID, @ClockInOutTime, @Type
    WHERE @Type = 'ClockIn';

    SELECT 'Punch recorded successfully at ' + CONVERT(VARCHAR, @ClockInOutTime, 120) AS Message;
END;
GO

-- 20. SubmitCorrectionRequest
CREATE PROCEDURE SubmitCorrectionRequest
    @EmployeeID INT,
    @Date DATE,
    @CorrectionType VARCHAR(50),
    @Reason VARCHAR(200)
AS
BEGIN
    INSERT INTO AttendanceCorrectionRequest (employee_id, date, correction_type, reason, status)
    VALUES (
        @EmployeeID,
        @Date,
        @CorrectionType,
        @Reason,
        'Pending'
    );

    SELECT 'Correction request submitted successfully for ' + CONVERT(VARCHAR, @Date, 23) AS Message;
END;
GO

-- 21. ViewRequestStatus
CREATE PROCEDURE ViewRequestStatus
    @EmployeeID INT
AS
BEGIN
    SELECT 
        request_id,
        date,
        correction_type,
        reason,
        status
    FROM AttendanceCorrectionRequest
    WHERE employee_id = @EmployeeID;
END;
GO

-- 23. AttachLeaveDocuments
CREATE PROCEDURE AttachLeaveDocuments
    @LeaveRequestID INT,
    @FilePath VARCHAR(200)
AS
BEGIN
    INSERT INTO LeaveDocument (leave_request_id, file_path, uploaded_at)
    VALUES (@LeaveRequestID, @FilePath, GETDATE());

    SELECT 'Document attached.' AS Message;
END;
GO

-- 24. ModifyLeaveRequest
CREATE PROCEDURE ModifyLeaveRequest
    @LeaveRequestID INT,
    @StartDate DATE,
    @EndDate DATE,
    @Reason VARCHAR(100)
AS
BEGIN
    UPDATE LeaveRequest
    SET justification = @Reason,
        duration = DATEDIFF(DAY, @StartDate, @EndDate) + 1
    WHERE request_id = @LeaveRequestID;

    SELECT 'Leave request ' + CAST(@LeaveRequestID AS VARCHAR) + ' modified successfully' AS Message;
END;
GO

-- 25. CancelLeaveRequest
CREATE PROCEDURE CancelLeaveRequest
    @LeaveRequestID INT
AS
BEGIN
    UPDATE LeaveRequest
    SET status = 'Cancelled'
    WHERE request_id = @LeaveRequestID;

    SELECT 'Leave request ' + CAST(@LeaveRequestID AS VARCHAR) + ' has been cancelled' AS Message;
END;
GO

-- 26. ViewLeaveBalance
CREATE PROCEDURE ViewLeaveBalance
    @EmployeeID INT
AS
BEGIN
    SELECT 
        le.leave_type_id,
        l.leave_type,
        le.entitlement AS RemainingLeaveDays
    FROM LeaveEntitlement le
    JOIN Leave l ON le.leave_type_id = l.leave_id
    WHERE le.employee_id = @EmployeeID;
END;
GO

-- 27. ViewLeaveHistory
CREATE PROCEDURE ViewLeaveHistory
    @EmployeeID INT
AS
BEGIN
    SELECT 
        lr.request_id,
        l.leave_type,
        lr.justification,
        lr.duration,
        lr.approval_timing,
        lr.status
    FROM LeaveRequest lr
    JOIN Leave l ON lr.leave_id = l.leave_id
    WHERE lr.employee_id = @EmployeeID;
END;
GO

--28. SubmitLeaveAfterAbsence
CREATE PROCEDURE SubmitLeaveAfterAbsence
    @EmployeeID INT,
    @LeaveTypeID INT,
    @StartDate DATE,
    @EndDate DATE,
    @Reason VARCHAR(100)
AS
BEGIN
    INSERT INTO LeaveRequest (employee_id, leave_id, justification, duration, status)
    VALUES (
        @EmployeeID,
        @LeaveTypeID,
        @Reason,
        DATEDIFF(DAY, @StartDate, @EndDate) + 1,
        'Pending'
    );

    SELECT 'Leave request submitted successfully for absence from ' + CONVERT(VARCHAR, @StartDate, 23) + ' to ' + CONVERT(VARCHAR, @EndDate, 23) AS Message;
END;
GO

--29. NotifyLeaveStatusChange
CREATE PROCEDURE NotifyLeaveStatusChange
    @EmployeeID INT,
    @RequestID INT,
    @Status VARCHAR(20)
AS
BEGIN
    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES (
        'Your leave request #' + CAST(@RequestID AS VARCHAR) + ' has been ' + @Status,
        'Medium',
        'LeaveStatus'
    );

    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status)
    VALUES (
        @EmployeeID,
        SCOPE_IDENTITY(),
        'Pending'
    );

    SELECT 'Notification sent: Leave request #' + CAST(@RequestID AS VARCHAR) + ' has been ' + @Status AS Message;
END;
GO
