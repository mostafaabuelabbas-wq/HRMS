using HRMS_M3.Areas.Employee.Services;
using HRMS_M3.Areas.Employee.Models;
using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3.Areas.Employee.Controllers
{
    [Area("Employee")]
    public class EmployeeController : Controller
    {
        private readonly EmployeeService _service;
        private readonly IWebHostEnvironment _env;

        public EmployeeController(EmployeeService service, IWebHostEnvironment env)
        {
            _service = service;
            _env = env;
        }

        // ----------------------------
        // 1. SHOW EMPLOYEE PROFILE
        // ----------------------------
        public async Task<IActionResult> Details(int id)
        {
            var emp = await _service.GetEmployeeByIdAsync(id);

            if (emp == null)
                return NotFound();

            return View(emp);
        }


        // ----------------------------
        // 2. SHOW EDIT PAGE
        // ----------------------------
        public async Task<IActionResult> Edit(int id)
        {
            var emp = await _service.GetEmployeeByIdAsync(id);

            if (emp == null)
                return NotFound();

            // Fill the form with existing data
            var vm = new EmployeeEditViewModel
            {
                Employee_Id = emp.Employee_Id,
                First_Name = emp.First_Name,
                Last_Name = emp.Last_Name,
                Email = emp.Email,
                Phone = emp.Phone,
                Address = emp.Address,
                Emergency_Contact_Name = emp.Emergency_Contact_Name,
                Emergency_Contact_Phone = emp.Emergency_Contact_Phone
            };

            return View(vm);
        }


        // ----------------------------
        // 3. SAVE EDITED PROFILE (POST)
        // ----------------------------
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(EmployeeEditViewModel vm)
        {
            if (!ModelState.IsValid)
                return View(vm);

            string imagePath = null;

            // Handle profile image upload
            if (vm.ProfileImageFile != null && vm.ProfileImageFile.Length > 0)
            {
                var folder = Path.Combine(_env.WebRootPath, "uploads", "profiles");

                if (!Directory.Exists(folder))
                    Directory.CreateDirectory(folder);

                var filename = $"{vm.Employee_Id}_{Guid.NewGuid()}{Path.GetExtension(vm.ProfileImageFile.FileName)}";
                var filepath = Path.Combine(folder, filename);

                using (var stream = System.IO.File.Create(filepath))
                {
                    await vm.ProfileImageFile.CopyToAsync(stream);
                }

                // save relative URL for DB
                imagePath = "/uploads/profiles/" + filename;
            }

            await _service.UpdateEmployeeAsync(vm, imagePath);

            return RedirectToAction("Details", new { id = vm.Employee_Id });
        }
    }
}
