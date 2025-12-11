using Microsoft.AspNetCore.Mvc;
using HRMS_M3.Areas.Employee.Services;
using HRMS_M3.Areas.Employee.Models;

namespace HRMS_M3.Areas.Employee.Controllers
{
    [Area("Employee")]
    public class RoleController : Controller
    {
        private readonly RoleService _roleService;
        private readonly EmployeeService _employeeService;

        public RoleController(RoleService roleService, EmployeeService employeeService)
        {
            _roleService = roleService;
            _employeeService = employeeService;
        }

        public async Task<IActionResult> Index()
        {
            var employees = await _roleService.GetAllEmployeesWithRolesAsync();

            var vm = employees.Select(e => new AssignRoleViewModel
            {
                Employee_Id = e.Employee_Id,
                Full_Name = e.Full_Name,
                CurrentRoleId = e.RoleID,
                CurrentRoleName = e.RoleName ?? "Unassigned"
            }).ToList();

            return View(vm);
        }

        public async Task<IActionResult> Edit(int id)
        {
            var employee = await _employeeService.GetEmployeeByIdAsync(id);
            var roles = await _roleService.GetRolesAsync();

            var vm = new AssignRoleViewModel
            {
                Employee_Id = employee.Employee_Id,
                Full_Name = employee.Full_Name,
                CurrentRoleId = employee.RoleID,
                CurrentRoleName = employee.RoleName,
                Roles = roles.ToList()
            };

            return View(vm);
        }

        [HttpPost]
        public async Task<IActionResult> Edit(AssignRoleViewModel vm)
        {
            await _roleService.AssignRoleAsync(vm.Employee_Id, vm.NewRoleId);
            return RedirectToAction("Index");
        }
    }
}
