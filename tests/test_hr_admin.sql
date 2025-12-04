/*

-- Check employee contract before creating a new one
SELECT employee_id, contract_id 
FROM Employee 
WHERE employee_id = 1;

-- List all existing contracts before
SELECT * FROM Contract ORDER BY contract_id;

-- Check subtype table before (FullTime example)
SELECT * FROM FullTimeContract ORDER BY contract_id;

EXEC CreateContract 
    @EmployeeID = 1,
    @Type = 'FullTime',
    @StartDate = '2025-01-01',
    @EndDate = '2025-12-31';

-- Employee should now reference new contract
SELECT employee_id, contract_id 
FROM Employee 
WHERE employee_id = 1;

-- New contract should exist
SELECT * FROM Contract WHERE contract_id = 4;

-- Subtype table must also contain new entry
SELECT * FROM FullTimeContract WHERE contract_id = 4;
*/
/*



-- 2 RenewContract
-- Before
SELECT * FROM Contract WHERE contract_id = 1;

-- Test RenewContract
EXEC RenewContract 1, '2026-01-01';

-- After
SELECT * FROM Contract WHERE contract_id = 1;
*/



-- 3 ApproveLeaveRequest
/*
-- Check the leave request before approval
SELECT request_id, employee_id, leave_id, status, approval_timing
FROM LeaveRequest
WHERE request_id = 2;   -- Example request (Sara’s Sick Leave)

-- Check subtype (VacationLeave) - should NOT change for sick leave
SELECT * FROM VacationLeave;

-- Check notifications before
SELECT * FROM Notification ORDER BY notification_id;

-- Check employee_notification before
SELECT * FROM Employee_Notification WHERE employee_id = 2;
EXEC ApproveLeaveRequest 
    @LeaveRequestID = 2,
    @ApproverID = 1,
    @Status = 'Approved';
    -- 1. Leave request should now be updated
SELECT request_id, employee_id, leave_id, status, approval_timing
FROM LeaveRequest
WHERE request_id = 2;

-- 2. Notification should now include the new message
SELECT TOP 1 * 
FROM Notification 
ORDER BY notification_id DESC;

-- 3. Employee_Notification should now have one row for employee 2
SELECT * 
FROM Employee_Notification
WHERE employee_id = 2;
*/


-- 4 AssignMission
/*
-- Check missions before
SELECT * FROM Mission ORDER BY mission_id;

-- Check notifications before
SELECT * FROM Notification ORDER BY notification_id;

-- Check employee notifications before
SELECT * FROM Employee_Notification WHERE employee_id = 2;   -- Example employee

EXEC AssignMission
    @EmployeeID = 2,
    @ManagerID = 1,
    @Destination = 'Dubai',
    @StartDate = '2025-01-10',
    @EndDate = '2025-01-15';


-- New mission should appear
SELECT TOP 1 * FROM Mission ORDER BY mission_id DESC;

-- New notification created
SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;

-- Notification assigned to employee
SELECT TOP 1 * 
FROM Employee_Notification 
WHERE employee_id = 2
ORDER BY delivered_at DESC;
*/

-- 5 ReviewReimbursement
/*
--before
SELECT reimbursement_id, employee_id, type, current_status, approval_date
FROM Reimbursement
WHERE reimbursement_id = 1;

SELECT * FROM Employee_Notification WHERE employee_id = 1;

SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;

EXEC ReviewReimbursement
    @ClaimID = 1,
    @ApproverID = 3,
    @Decision = 'Approved';

 -- Reimbursement must now be updated
SELECT reimbursement_id, employee_id, type, current_status, approval_date
FROM Reimbursement
WHERE reimbursement_id = 1;

-- Check the new notification
SELECT TOP 1 * FROM Notification ORDER BY notification_id DESC;

-- Confirm employee received the notification
SELECT TOP 1 *
FROM Employee_Notification
WHERE employee_id = 1
ORDER BY delivered_at DESC;
*/


-- 6 GetActiveContracts
/*
SELECT * FROM Contract;

SELECT employee_id, full_name, contract_id 
FROM Employee;

SELECT department_id, department_name 
FROM Department;

EXEC GetActiveContracts;
*/

-- 7 GetTeamByManager
/*
SELECT employee_id, full_name, manager_id, is_active
FROM Employee
ORDER BY employee_id;
SELECT * FROM Position;
SELECT * FROM Department;

EXEC GetTeamByManager @ManagerID = 1;
*/
/*
-- 8 UpdateLeavePolicy
--before
SELECT policy_id, name, eligibility_rules, notice_period
FROM LeavePolicy
WHERE policy_id = 1;

EXEC UpdateLeavePolicy
    @PolicyID = 1,
    @EligibilityRules = 'Minimum 2 years experience',
    @NoticePeriod = 30;

-- Check updated policy
SELECT policy_id, name, eligibility_rules, notice_period
FROM LeavePolicy
WHERE policy_id = 1;
*/

/*
-- 9 GetExpiringContracts
SELECT contract_id, type, end_date 
FROM Contract;

SELECT employee_id, full_name, contract_id 
FROM Employee;

SELECT department_id, department_name 
FROM Department;

EXEC GetExpiringContracts @DaysBefore = 400;
*/

/*
-- 10 AssignDepartmentHead
SELECT department_id, department_name, department_head_id
FROM Department
ORDER BY department_id;

SELECT employee_id, full_name
FROM Employee
ORDER BY employee_id;

EXEC AssignDepartmentHead 
    @DepartmentID = 2,
    @ManagerID = 1;
-- Check updated department head
SELECT department_id, department_name, department_head_id
FROM Department
WHERE department_id = 2;
*/
