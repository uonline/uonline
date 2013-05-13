<?php

$time_start = microtime(true);

require_once 'utils.php';
require_once './Twig/Autoloader.php';
require_once './Silex/autoload.php';
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

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
	'databaseIsOutdated' => BASE_OUTDATED,
);




/********************** main page **********************/
$app->get('/', function () use ($app, $twig, $options, $s) {
	return
		sessionActive($s) ?
		$app->redirect('/game/') :
		$app->redirect('/'.DEFAULT_INSTANCE.'/');
});



/********************** about **********************/
$app->get('/about/', function () use ($app, $twig, $options, $s) {
	$options['instance'] = 'about';
	return $twig->render( 'about.twig', $options);
});




/********************** register **********************/
$app->get('/register/', function () use ($app, $twig, $options, $s) {
	$options['instance'] = 'register';
	return $twig->render( 'register.twig', $options);
});

$app->post('/register/', function (Request $r) use ($app, $twig, $options, $s) {
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
		$options['instance'] = 'register';
		return $twig->render( 'register.twig', $options);
	}
});




/********************** login **********************/
$app->get('/login/', function () use ($app, $twig, $options, $s) {
	$options['instance'] = 'login';
	return $twig->render( 'login.twig', $options);
});

$app->post('/login/', function (Request $r) use ($app, $twig, $options, $s) {
	$u = $r->get('user'); $p = $r->get('pass');
	if (accessGranted($u, $p)) {
		$s = setSession($u);
		setMyCookie('sessid', $s);
		return $app->redirect('/');
	}
	else {
		$error = true;
		//if (!correctUserName($u) || !correctPassword($p)) $error = true;
		//elseif (!userExists($u)) $error = true;
		//else $error = true;
	}
	$options['user'] = $u;
	$options['error'] = $error;
	$options['instance'] = 'login';
	return $twig->render( 'login.twig', $options);
});



/********************** profile **********************/
$app->get('/profile/', function () use ($app, $twig, $options, $s) {
	if (sessionExpired($s)) return $app->redirect('/login/');
	$chrs = userCharacters($s);
	$options['profileIsMine'] = true;
	$options['instance'] = 'profile';
	return $twig->render( 'profile.twig', $options + $chrs);
});

$app->get('/profile/id/{id}/', function ($id) use ($app, $twig, $options, $s) {
	if (!idExists($id)) return $twig->render( '404.twig', $options);
	$chrs = userCharacters($id, 'id');
	$options['profileIsMine'] = idBySession($s) === $id;
	$options['instance'] = 'profile';
	return $twig->render( 'profile.twig', $options + $chrs);
})
->assert('id', '\d+');

$app->get('/profile/user/{user}/', function ($user) use ($app, $twig, $options, $s) {
	if (!userExists($user)) return $twig->render( '404.twig', $options);
	$chrs = userCharacters($user, 'user');
	$options['profileIsMine'] = userBySession($s) === $user;
	$options['instance'] = 'profile';
	return $twig->render( 'profile.twig', $options + $chrs);
});




/********************** logout **********************/
$app->get('/action/logout', function () use ($app, $twig, $options, $s) {
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
		$options['fight_mode'] = fightMode($s, 'fight_mode');
		$options['autoinvolved_fm'] = fightMode($s, 'autoinvolved_fm');
		$options['instance'] = 'game';
		return $twig->render( 'game.twig', $options);
	}
});



/********************** moving **********************/
$app->get('/action/go/{to}', function ($to) use ($app, $twig, $options, $s) {
	changeLocation($s, $to);
	return $app->redirect('/game/');
})
->assert('to', '\d+');

$app->get('/action/attack', function () use ($app, $twig, $options, $s) {
	goAttack($s);
	return $app->redirect('/game/');
});

$app->get('/action/escape', function () use ($app, $twig, $options, $s) {
	goEscape($s);
	return $app->redirect('/game/');
});


/********************** stats **********************/
$app->get('/stats/', function () use ($app, $twig, $options, $s) {
	goAttack($s);
	return $twig->render( 'stats.twig', $options);
});

/********************** world **********************/
$app->get('/world/', function () use ($app, $twig, $options, $s) {
	return $twig->render( 'world.twig', $options);
});

/********************** guidelines **********************/
$app->get('/development/', function () use ($app, $twig, $options, $s) {
	return $twig->render( 'development.twig', $options);
});

/********************** others **********************/
$app->error(function (Exception $e, $с) use ($app, $twig, $options, $s) {
	switch ($с) {
		case 404:
			return $twig->render( '404.twig', $options);
		default:
			return $twig->render( '404.twig', $options);
	}
});


$app->run();



$time_end = microtime(true);
stats($time_end - $time_start);
echo "\n<!-- Done in " . ( ($time_end - $time_start) * 1000) . ' milliseconds -->';



?>
