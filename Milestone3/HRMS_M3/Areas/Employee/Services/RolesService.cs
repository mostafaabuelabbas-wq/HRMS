using Dapper;
using HRMS_M3.Areas.Employee.Models;
using System.Data;

namespace HRMS_M3.Areas.Employee.Services
{
    public class RoleService
    {
        private readonly DbService _db;

        public RoleService(DbService db)
        {
            _db = db;
        }

        // Get all roles
        public async Task<IEnumerable<RoleDto>> GetRolesAsync()
        {
            return await _db.QueryAsync<RoleDto>("GetAllRoles", null);
        }

        // Assign a role to employee
        public async Task AssignRoleAsync(int employeeId, int roleId)
        {
            await _db.ExecuteAsync("AssignRole", new { EmployeeID = employeeId, RoleID = roleId });
        }
        // RoleService.cs (Add this method)
        public async Task<IEnumerable<EmployeeDto>> GetAllEmployeesWithRolesAsync()
        {
            return await _db.QueryAsync<EmployeeDto>("GetAllEmployees_Roles", null);
        }
    }
}
