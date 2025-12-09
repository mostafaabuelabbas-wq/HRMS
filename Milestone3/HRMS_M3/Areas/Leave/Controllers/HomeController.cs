using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3.Areas.Leave.Controllers
{
    [Area("Leave")]
    public class HomeController : Controller
    {
        public IActionResult Index()
        {
            return View();
        }
    }
}
