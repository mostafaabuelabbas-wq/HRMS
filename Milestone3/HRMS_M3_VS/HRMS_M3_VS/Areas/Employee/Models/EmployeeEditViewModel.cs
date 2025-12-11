using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3_VS.Areas.Employee.Models
{
    public class EmployeeEditViewModel : Controller
    {
        public IActionResult Index()
        {
            return View();
        }
    }
}
