<?php

$time_start = microtime(true);

require_once 'utils.php';
require_once './Twig/Autoloader.php';
require_once './silex/vendor/autoload.php';
use Symfony\Component\HttpFoundation\Request;

Twig_Autoloader::register();
$loader = new Twig_Loader_Filesystem('./templates');
$twig = new Twig_Environment($loader, array('cache' => TWIG_CACHE));
$twig->addFilter(new Twig_SimpleFilter('tf', 'tf', array('pre_escape' => 'html', 'is_safe' => array('html') ) ) );
$twig->addFilter(new Twig_SimpleFilter('nl2p', 'nl2p', array('pre_escape' => 'html', 'is_safe' => array('html') ) ) );

$app = new Silex\Application();
$app['debug'] = true;

$s = $_COOKIE['sessid']; refreshSession($s);
$options = array(
	'admin' => userPermissions($s) && sessionActive($s),
	'loggedIn' => sessionActive($s),
	'login' => userBySession($s),
	'mail_count' => 0,
);




/********************** main page **********************/
$app->get('/', function () use ($app) {
	return $app->redirect('/'.DEFAULT_INSTANCE.'/');
});



/********************** about **********************/
$app->get('/about/', function () use ($twig, $options) {
	return $twig->render( 'about.twig', $options + array('instance' => 'about') );
});




/********************** register **********************/
$app->get('/register/', function () use ($twig, $options) {
	return $twig->render( 'register.twig', $options + array('instance' => 'register')  );
});

$app->post('/register/', function (Request $r) use ($app, $twig, $options) {
	$u = $r->get('user'); $p = $r->get('pass');
		if (allowToRegister($u, $p)) {
			$s = registerUser($u, $p);
			setMyCookie('sessid', $s);
			return $app->redirect('/'.DEFAULT_INSTANCE.'/');
		}
		else {
			$error = true;
			//if ( !correctUserName($u) || !correctPassword($p) ) $error = true;
			//elseif (userExists($u)) $error = true;
			//else $error = true;
			$options['invalidLogin'] = !correctUserName($u); // логин хуйня
			$options['invalidPass'] = !correctPassword($p); // тут хуйня
			$options['loginIsBusy'] = userExists($u); // логин занят
			$options['user'] = $u;
			$options['pass'] = $p;
			$options['error'] = $error;
		}
	return $twig->render( 'register.twig', $options + array('instance' => 'register') );
});




/********************** login **********************/
$app->get('/login/', function () use ($twig, $options) {
	return $twig->render( 'login.twig', $options + array('instance' => 'login') );
});

$app->post('/login/', function (Request $r) use ($app, $twig, $options) {
	$u = $r->get('user'); $p = $r->get('pass');
	if (accessGranted($u, $p)) {
		$s = setSession($u);
		setMyCookie('sessid', $s);
		return $app->redirect('/'.DEFAULT_INSTANCE.'/');
	}
	else {
		$error = true;
		//if (!correctUserName($u) || !correctPassword($p)) $error = true;
		//elseif (!userExists($u)) $error = true;
		//else $error = true;
	}
	$options['user'] = $u;
	$options['error'] = $error;
	return $twig->render( 'login.twig', $options + array('instance' => 'login') );
});



/********************** profile **********************/
$app->get('/profile/', function () use ($twig, $options, $s) {
	if (sessionExpired($s)) return $app->redirect('/login/');
	$chrs = userCharacters($s);
	return $twig->render( 'profile.twig', $options + $chrs + array('instance' => 'profile') );
});

$app->get('/profile/id/{id}/', function ($id) use ($twig, $options) {
	$chrs = userCharacters($id, 'id');
	return $twig->render( 'profile.twig', $options + $chrs + array('instance' => 'profile') );
})
->assert('id', '\d+');

$app->get('/profile/user/{user}/', function ($user) use ($twig, $options) {
	$chrs = userCharacters($user, 'user');
	return $twig->render( 'profile.twig', $options + $chrs + array('instance' => 'profile') );
});




/********************** logout **********************/
$app->get('/logout/', function () use ($app, $s) {
	closeSession($s);
	return $app->redirect('/'.DEFAULT_INSTANCE.'/');
});




/********************** game **********************/
$app->get('/game/', function () use ($app, $twig, $options, $s) {

	if (sessionExpired($s)) return $app->redirect('/login/');
	else {
		$options['location_name'] = currentLocationTitle($s);
		$options['area_name'] = currentAreaTitle($s);
		$options['pic'] = '/img/Sasuke.jpeg';
		$options['description'] = currentLocationDescription($s);
		$options['ways'] = allowedZones($s);
		$options['players_list'] = usersOnLocation($s);
		$options['monsters_list'] = monstersOnLocation($s);
	}
	return $twig->render( 'game.twig', $options + array('instance' => 'game') );
});



/********************** moving **********************/
$app->get('/game/go/{to}/', function ($to) use ($app, $s) {
	changeLocation($s, $to);
	return $app->redirect('/game/');
});



$app->run();



$time_end = microtime(true);
stats($time_end - $time_start);
echo "\n<!-- Done in " . ( ($time_end - $time_start) * 1000) . ' milliseconds -->';



?>
