using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3.Areas.Attendance.Controllers
{
    [Area("Attendance")]
    public class HomeController : Controller
    {
        public IActionResult Index()
        {
            return View();
        }
    }
}
