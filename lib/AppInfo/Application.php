<?php
namespace OCA\Audio2Text\AppInfo;

use OCP\AppFramework\App;
use OCA\Audio2Text\Controller\TranscribeController;
use OCA\Audio2Text\Service\TranscribeService;

class Application extends App {

    public function __construct(array $urlParams = []) {
        parent::__construct('audio2text', $urlParams);

        $container = $this->getContainer();

        // Register services
        $container->registerService('TranscribeService', function($c) {
            return new TranscribeService(
                $c->query('ServerContainer')->getRootFolder(),
                $c->query('ServerContainer')->getConfig(),
                $c->query('ServerContainer')->getLogger()
            );
        });

        // Register controllers
        $container->registerService('TranscribeController', function($c) {
            return new TranscribeController(
                $c->query('AppName'),
                $c->query('Request'),
                $c->query('ServerContainer')->getConfig(),
                $c->query('ServerContainer')->getUserSession(),
                $c->query('TranscribeService')
            );
        });
    }
}
