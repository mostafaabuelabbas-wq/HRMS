using Microsoft.AspNetCore.Mvc;

namespace HRMS_M3.Areas.Missions.Controllers
{
    [Area("Missions")]
    public class HomeController : Controller
    {
        public IActionResult Index()
        {
            return View();
        }
    }
}
