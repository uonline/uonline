<!DOCTYPE html>
<html>
	<head>
		<meta charset="utf-8" />
		<title>Технические работы</title>
	</head>
	<body>
		<div style="max-width: 60em; margin: 0 auto; text-align: center;">
			<h1>Извините!</h1>
			<p style="margin-bottom: 2.5em;">Запрос не&nbsp;может быть выполнен, потому что на&nbsp;сервере идут технические работы.</p>

<?php if (!$maintenance_message) { ?>
			<p>Администратор, включивший этот режим, никак не&nbsp;прокомментировал своё решение&nbsp;&mdash; возможно, случилось что-то непредвиденное.</p>
<?php } else { ?>
			<p>Вот что сказал администратор, включивший этот режим:</p>
			<p><span style="color: gray; font-size: 125%;">&laquo;</span><?php echo htmlspecialchars($maintenance_message); ?><span style="color: gray; font-size: 125%;">&raquo;</span></p>
<?php } ?>

		</div>
	</body>
</html>
