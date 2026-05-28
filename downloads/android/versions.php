<?php
// Manifest des builds Android — généré dynamiquement.
// Scan le dossier courant pour tous les piloo-vX.Y.Z.apk présents, trie
// par semver descendant et renvoie un JSON.
// Pour ajouter une version : il suffit de scp/rsync le .apk ici, aucun
// commit nécessaire. L'index.html consomme la même forme JSON qu'avant.

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: public, max-age=60');

$dir = __DIR__;
$files = glob($dir . '/piloo-v*.apk');
$out = [];

foreach ($files as $path) {
    $name = basename($path);
    if (!preg_match('/^piloo-v(\d+)\.(\d+)\.(\d+)\.apk$/', $name, $m)) {
        continue;
    }
    $version = "v{$m[1]}.{$m[2]}.{$m[3]}";
    $out[] = [
        'version'   => $version,
        'sortKey'   => [(int)$m[1], (int)$m[2], (int)$m[3]],
        'published' => gmdate('Y-m-d\TH:i:s\Z', filemtime($path)),
        'size'      => filesize($path),
        'file'      => $name,
    ];
}

// Tri semver desc (major, minor, patch).
usort($out, function ($a, $b) {
    return $b['sortKey'] <=> $a['sortKey'];
});

// On retire la clé interne avant l'envoi.
foreach ($out as &$v) {
    unset($v['sortKey']);
}

echo json_encode($out, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
