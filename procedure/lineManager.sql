--Line Manager

-- 1. ReviewLeaveRequest
CREATE PROCEDURE ReviewLeaveRequest
    @LeaveRequestID INT,
    @ManagerID INT,
    @Decision VARCHAR(20)
AS
BEGIN
    UPDATE LeaveRequest
    SET status = @Decision, 
        approval_timing = GETDATE()
    WHERE request_id = @LeaveRequestID;
    
    SELECT @LeaveRequestID AS LeaveRequestID, 
           @ManagerID AS ManagerID, 
           @Decision AS Decision;
END;
GO


-- 2. AssignShift
CREATE PROCEDURE AssignShift
    @EmployeeID INT,
    @ShiftID INT
AS
BEGIN
    INSERT INTO ShiftAssignment (employee_id, shift_id, start_date, status)
    VALUES (@EmployeeID, @ShiftID, GETDATE(), 'Active');
    
    SELECT 'Shift assigned successfully' AS ConfirmationMessage;
END;
GO


-- 3. ViewTeamAttendance
CREATE PROCEDURE ViewTeamAttendance
    @ManagerID INT,
    @DateRangeStart DATE,
    @DateRangeEnd DATE
AS
BEGIN
    SELECT 
        a.*,
        e.full_name
    FROM Attendance a
    INNER JOIN Employee e ON a.employee_id = e.employee_id
    WHERE e.manager_id = @ManagerID
        AND CAST(a.entry_time AS DATE) BETWEEN @DateRangeStart AND @DateRangeEnd;
END;
GO


-- 4. SendTeamNotification
CREATE PROCEDURE SendTeamNotification
    @ManagerID INT,
    @MessageContent VARCHAR(255),
    @UrgencyLevel VARCHAR(50)
AS
BEGIN
    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES (@MessageContent, @UrgencyLevel, 'Team Notification');
    
    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status)
    SELECT employee_id, SCOPE_IDENTITY(), 'Pending'
    FROM Employee
    WHERE manager_id = @ManagerID;
    
    SELECT 'Notification sent to team successfully' AS ConfirmationMessage;
END;
GO


-- 5. ApproveMissionCompletion
CREATE PROCEDURE ApproveMissionCompletion
    @MissionID INT,
    @ManagerID INT,
    @Remarks VARCHAR(200)
AS
BEGIN
    UPDATE Mission
    SET status = 'Completed'
    WHERE mission_id = @MissionID
        AND manager_id = @ManagerID;
    
    SELECT 'Mission completed successfully' AS ConfirmationMessage,
           @Remarks AS Remarks;
END;
GO


-- 6. RequestReplacement
CREATE PROCEDURE RequestReplacement
    @EmployeeID INT,
    @Reason VARCHAR(150)
AS
BEGIN
    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES ('Replacement needed for Employee ID: ' + CAST(@EmployeeID AS VARCHAR) + '. Reason: ' + @Reason, 
            'High', 
            'Replacement Request');
    
    SELECT 'Replacement request submitted successfully' AS ConfirmationMessage,
           @Reason AS Reason;
END;
GO


-- 7. ViewDepartmentSummary
CREATE PROCEDURE ViewDepartmentSummary
    @DepartmentID INT
AS
BEGIN
    SELECT 
        COUNT(e.employee_id) AS EmployeeCount,
        COUNT(DISTINCT m.mission_id) AS ActiveProjects
    FROM Department d
    LEFT JOIN Employee e ON d.department_id = e.department_id
    LEFT JOIN Mission m ON e.employee_id = m.employee_id AND m.status = 'Active'
    WHERE d.department_id = @DepartmentID;
END;
GO


-- 8. ReassignShift
CREATE PROCEDURE ReassignShift
    @EmployeeID INT,
    @OldShiftID INT,
    @NewShiftID INT
AS
BEGIN
    UPDATE ShiftAssignment
    SET shift_id = @NewShiftID
    WHERE employee_id = @EmployeeID
        AND shift_id = @OldShiftID
        AND status = 'Active';
    
    SELECT 'Shift reassigned successfully' AS ConfirmationMessage;
END;
GO


-- 9. GetPendingLeaveRequests
CREATE PROCEDURE GetPendingLeaveRequests
    @ManagerID INT
AS
BEGIN
    SELECT 
        lr.*,
        e.full_name AS EmployeeName,
        l.leave_type AS LeaveType
    FROM LeaveRequest lr
    INNER JOIN Employee e ON lr.employee_id = e.employee_id
    INNER JOIN Leave l ON lr.leave_id = l.leave_id
    WHERE e.manager_id = @ManagerID
        AND lr.status = 'Pending';
END;
GO


-- 10. GetTeamStatistics
CREATE PROCEDURE GetTeamStatistics
    @ManagerID INT
AS
BEGIN
    SELECT 
        COUNT(e.employee_id) AS TeamSize,
        AVG(p.base_amount) AS AverageSalary,
        @ManagerID AS ManagerID
    FROM Employee e
    LEFT JOIN Payroll p ON e.employee_id = p.employee_id
    WHERE e.manager_id = @ManagerID;
END;
GO


-- 11. ViewTeamProfiles
CREATE PROCEDURE ViewTeamProfiles
    @ManagerID INT
AS
BEGIN
    SELECT 
        e.employee_id,
        e.full_name,
        e.email,
        e.phone,
        e.hire_date,
        e.employment_status,
        d.department_name,
        p.position_title
    FROM Employee e
    LEFT JOIN Department d ON e.department_id = d.department_id
    LEFT JOIN Position p ON e.position_id = p.position_id
    WHERE e.manager_id = @ManagerID;
END;
GO


-- 12. GetTeamSummary
CREATE PROCEDURE GetTeamSummary
    @ManagerID INT
AS
BEGIN
    SELECT 
        r.role_name,
        d.department_name,
        COUNT(e.employee_id) AS EmployeeCount,
        AVG(DATEDIFF(YEAR, e.hire_date, GETDATE())) AS AverageTenureYears
    FROM Employee e
    LEFT JOIN Employee_Role er ON e.employee_id = er.employee_id
    LEFT JOIN Role r ON er.role_id = r.role_id
    LEFT JOIN Department d ON e.department_id = d.department_id
    WHERE e.manager_id = @ManagerID
    GROUP BY r.role_name, d.department_name;
END;
GO
-- 13. FilterTeamProfiles
CREATE PROCEDURE FilterTeamProfiles
    @ManagerID INT,
    @Skill VARCHAR(50),
    @RoleID INT
AS
BEGIN
    SELECT DISTINCT e.*
    FROM Employee e
    LEFT JOIN Employee_Skill es ON e.employee_id = es.employee_id
    LEFT JOIN Skill s ON es.skill_id = s.skill_id
    LEFT JOIN Employee_Role er ON e.employee_id = er.employee_id
    WHERE e.manager_id = @ManagerID
        AND (s.skill_name = @Skill OR er.role_id = @RoleID);
END;
GO
-- 14. ViewTeamCertifications
CREATE PROCEDURE ViewTeamCertifications
    @ManagerID INT
AS
BEGIN
    SELECT 
        e.full_name,
        s.skill_name,
        es.proficiency_level,
        v.verification_type,
        v.issuer,
        v.issue_date,
        v.expiry_period
    FROM Employee e
    LEFT JOIN Employee_Skill es ON e.employee_id = es.employee_id
    LEFT JOIN Skill s ON es.skill_id = s.skill_id
    LEFT JOIN Employee_Verification ev ON e.employee_id = ev.employee_id
    LEFT JOIN Verification v ON ev.verification_id = v.verification_id
    WHERE e.manager_id = @ManagerID;
END;
GO


-- 15. AddManagerNotes check visible to hr
CREATE PROCEDURE AddManagerNotes
    @EmployeeID INT,
    @ManagerID INT,
    @Note VARCHAR(500)
AS
BEGIN
    INSERT INTO ManagerNotes (employee_id, manager_id, note_content, created_at)
    VALUES (@EmployeeID, @ManagerID, @Note, GETDATE());
    
    SELECT 'Manager note added successfully' AS Message;
END;
GO


-- 16. RecordManualAttendance
CREATE PROCEDURE RecordManualAttendance
    @EmployeeID INT,
    @Date DATE,
    @ClockIn TIME,
    @ClockOut TIME,
    @Reason VARCHAR(200),
    @RecordedBy INT
AS
BEGIN
    INSERT INTO Attendance (employee_id, entry_time, exit_time, login_method, logout_method)
    VALUES (@EmployeeID, 
            CAST(@Date AS DATETIME) + CAST(@ClockIn AS DATETIME), 
            CAST(@Date AS DATETIME) + CAST(@ClockOut AS DATETIME), 
            'Manual Entry', 
            'Manual Entry');
    
    INSERT INTO AttendanceLog (attendance_id, actor, timestamp, reason)
    VALUES (SCOPE_IDENTITY(), @RecordedBy, GETDATE(), @Reason);
    
    SELECT 'Manual attendance recorded successfully with audit trail' AS Message;
END;
GO
-- 17. ReviewMissedPunches
CREATE PROCEDURE ReviewMissedPunches
    @ManagerID INT,
    @Date DATE
AS
BEGIN
    SELECT 
        e.full_name,
        a.attendance_id,
        a.entry_time,
        a.exit_time,
        a.duration
    FROM Attendance a
    INNER JOIN Employee e ON a.employee_id = e.employee_id
    WHERE e.manager_id = @ManagerID
        AND CAST(a.entry_time AS DATE) = @Date
        AND (a.entry_time IS NULL OR a.exit_time IS NULL);
END;
GO


-- 18. ApproveTimeRequest
CREATE PROCEDURE ApproveTimeRequest
    @RequestID INT,
    @ManagerID INT,
    @Decision VARCHAR(20),
    @Comments VARCHAR(200)
AS
BEGIN
    UPDATE AttendanceCorrectionRequest
    SET status = @Decision
    WHERE request_id = @RequestID;
    
    SELECT 'Time request processed successfully' AS ConfirmationMessage,
           @Decision AS Decision,
           @Comments AS Comments;
END;
GO


-- 19. ViewLeaveRequest
CREATE PROCEDURE ViewLeaveRequest
    @LeaveRequestID INT,
    @ManagerID INT
AS
BEGIN
    SELECT 
        lr.*,
        e.full_name,
        l.leave_type
    FROM LeaveRequest lr
    INNER JOIN Employee e ON lr.employee_id = e.employee_id
    INNER JOIN Leave l ON lr.leave_id = l.leave_id
    WHERE lr.request_id = @LeaveRequestID
        AND e.manager_id = @ManagerID;
END;
GO


-- 20. ApproveLeaveRequest
CREATE OR ALTER PROCEDURE ApproveLeaveRequest
    @LeaveRequestID INT,
    @ManagerID INT
AS
BEGIN
    UPDATE LeaveRequest
    SET status = 'Approved',
    approval_timing = GETDATE()
    WHERE request_id = @LeaveRequestID;
    SELECT 'Leave request approved successfully' AS ConfirmationMessage;
END;
GO


-- 21. RejectLeaveRequest
CREATE PROCEDURE RejectLeaveRequest
    @LeaveRequestID INT,
    @ManagerID INT,
    @Reason VARCHAR(200)
AS
BEGIN
    UPDATE LeaveRequest
    SET status = 'Rejected',
        approval_timing = GETDATE()
    WHERE request_id = @LeaveRequestID;
    
    SELECT 'Leave request rejected successfully' AS ConfirmationMessage,
           @Reason AS RejectionReason;
END;
GO


-- 22. DelegateLeaveApproval
CREATE PROCEDURE DelegateLeaveApproval
    @ManagerID INT,
    @DelegateID INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES ('Leave approval authority delegated from Manager ID: ' + CAST(@ManagerID AS VARCHAR) + 
            ' to Delegate ID: ' + CAST(@DelegateID AS VARCHAR) + 
            ' from ' + CAST(@StartDate AS VARCHAR) + ' to ' + CAST(@EndDate AS VARCHAR), 
            'High', 
            'Delegation Notice');
    
    SELECT 'Leave approval authority delegated successfully' AS ConfirmationMessage,
           @DelegateID AS DelegateID,
           @StartDate AS StartDate,
           @EndDate AS EndDate;
END;
GO


-- 23. FlagIrregularLeave
CREATE PROCEDURE FlagIrregularLeave
    @EmployeeID INT,
    @ManagerID INT,
    @PatternDescription VARCHAR(200)
AS
BEGIN
    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES ('Irregular leave pattern flagged for Employee ID: ' + CAST(@EmployeeID AS VARCHAR) + 
            '. Pattern: ' + @PatternDescription + 
            '. Flagged by Manager ID: ' + CAST(@ManagerID AS VARCHAR), 
            'Medium', 
            'Leave Pattern Alert');
    
    SELECT 'Irregular leave pattern flagged successfully' AS ConfirmationMessage;
END;
GO


-- 24. NotifyNewLeaveRequest
CREATE PROCEDURE NotifyNewLeaveRequest
    @ManagerID INT,
    @RequestID INT
AS
BEGIN
    INSERT INTO Notification (message_content, urgency, notification_type)
    VALUES ('New leave request ID: ' + CAST(@RequestID AS VARCHAR) + ' has been assigned to you for review.', 
            'High', 
            'Leave Request Assignment');
    
    INSERT INTO Employee_Notification (employee_id, notification_id, delivery_status)
    VALUES (@ManagerID, SCOPE_IDENTITY(), 'Pending');
    
    SELECT 'New leave request ID: ' + CAST(@RequestID AS VARCHAR) + ' has been assigned to you for review.' AS NotificationMessage;
END;
GO