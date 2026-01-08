<?php

namespace App\Controller;

use App\Service\PortfolioDataService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

class HomeController extends AbstractController
{
    public function __construct(
        private readonly PortfolioDataService $portfolioData
    ) {
    }

    #[Route('/', name: 'home')]
    public function index(): Response
    {
        return $this->render('home/index.html.twig', [
            'title' => $this->portfolioData->getTitle(),
            'skills' => $this->portfolioData->getSkills(),
            'projects' => $this->portfolioData->getProjects(),
        ]);
    }
}
