#!/usr/bin/php
<?php
define('SERVER_URL','http://kernel.ubuntu.com/~kernel-ppa/mainline/');

$dom = new domDocument();

echo 'Getting kernel list...';
$dom->loadHTMLFile(SERVER_URL);
echo 'done'.PHP_EOL;

$sxml = simplexml_import_dom($dom);
$sxml_rows = $sxml->xpath('//tr/td/a');

$kernels = array();

foreach ($sxml_rows as $sxml_row){
	$string = (string)$sxml_row;
	$matches = array();
	#if (preg_match('/^v(4\\.[0-9]+)(?:\\.([\\.0-9]+))?(?:-rc([0-9]+))?(?:-([a-z]+))\\/$/',$string,$matches)){
	if (preg_match('/^v([456]\\.[0-9]+)(?:\\.([\\.0-9]+))?(?:-rc([0-9]+))?\\/$/',$string,$matches)){
		array_shift($matches);
		//$version = array_shift($matches);
		//$kernels[$version][] = $string.' '.implode(' ',$matches);
		$kernels[$matches[0]][] = array($string,$matches);
	}
}

function compare_kernel($j, $k){
	//0 kernel version - ignored

	//1 kernel subversion - empty = 0
	$j_sub = explode('.',$j[1] ?? '-1');
	$k_sub = explode('.',$k[1] ?? '-1');
	$i = 0;
	do {
		$j_set = isset($j_sub[$i]);
		$k_set = isset($k_sub[$i]);
		$j_val = $j_set ? intval($j_sub[$i]) : 0;
		$k_val = $k_set ? intval($k_sub[$i]) : 0;
		$i++;
		if ($j_val !== $k_val) return $j_val > $k_val;
	} while ($j_set || $k_set);
	
	//2 rc flag
	$j_val = intval($j[2]);
	$k_val = intval($k[2]);
	if ($j_val !== $k_val){
		if ($j_val === 0) return true;
		return $j_val > $k_val && $k_val !== 0;
	}

	//3 release
//	$j_val = substr($j[3],0,1);
//	$k_val = substr($k[3],0,1);
//	if ($j_val !== $k_val) return $j_val > $k_val;
	
	throw new Exception();
}

$kernels = array_map(function($kernel){
	//var_dump($kernel);
	$reduced = array_reduce($kernel,function($j, $k){
		if (is_null($j)) return $k;
		return compare_kernel($j[1],$k[1]) ? $j : $k;
	});
	return $reduced[0];
},$kernels);

foreach ($kernels as $version => $version_long){
	echo $version.'	'.$version_long.PHP_EOL;
}

do {
	if ($argc > 1){
		if (strlen($kernel = trim($argv[1])) == 0) throw new Exception('Could not find requested kernel!');
		$valid = isset($kernels[$kernel]);
		if (!$valid) throw new Exception('Could not find requested kernel!');
	} else {
		echo 'Enter kernel version: ';
		$kernel = trim(fgets(STDIN));
		$valid = isset($kernels[$kernel]);
		if (!$valid) echo 'Invalid entry.'.PHP_EOL;
	}
} while (!$valid);

$arch = trim(`dpkg --print-architecture`);
$dom->loadHTMLFile($kernel_url = SERVER_URL.$kernels[$kernel]);
$sxml = simplexml_import_dom($dom);
if ($sxml_rows = $sxml->xpath("//tr/td/a[text()=\"$arch/\"]")){
	$dom->loadHTMLFile($kernel_url = SERVER_URL.$kernels[$kernel].$arch.'/');
	echo $kernel_url.PHP_EOL;
	$sxml = simplexml_import_dom($dom);
}
$sxml_rows = $sxml->xpath('//tr/td/a[starts-with(text(),"linux-")]');

$install_command = ($_SERVER['USER'] == 'root' ? '' : 'sudo ').'dpkg -i';

foreach ($sxml_rows as $sxml_row){
	$string = (string)$sxml_row;
	if (preg_match('/(amd64|all)\\.deb$/',$string)){
		if (strpos($string,'lowlatency') !== false) continue;
		echo $string.PHP_EOL;
		copy($kernel_url.$string,$string);
		$install_command .= ' '.$string;
	}
}
if ($argc > 1){
	if (isset($argv[2]) && strtolower(substr(trim($argv[1]),0,1)) == 'y') passthru($install_command);
} else {
	echo 'Install? ';
	if (strtolower(substr(trim(fgets(STDIN)),0,1)) == 'y') passthru($install_command);
}
?>
