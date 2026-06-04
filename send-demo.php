<?php
/**
 * Dataferme — Traitement du formulaire de demande de démo
 * Hébergement : O2switch (PHP mail())
 *
 * Envoi :
 *   1. Notification à contact@homabot.com
 *   2. Email de confirmation à l'éleveur
 */

header('Content-Type: application/json; charset=utf-8');

/* ── Helpers ──────────────────────────────────────────────── */

function sanitize(string $val): string {
    return htmlspecialchars(strip_tags(trim($val)), ENT_QUOTES, 'UTF-8');
}

function encodeSubject(string $subject): string {
    return '=?UTF-8?B?' . base64_encode($subject) . '?=';
}

function jsonError(string $msg): void {
    echo json_encode(['success' => false, 'error' => $msg]);
    exit;
}

/* ── Collecte & validation des champs ────────────────────── */

$firstName = sanitize($_POST['firstName'] ?? '');
$lastName  = sanitize($_POST['lastName']  ?? '');
$email     = filter_var(trim($_POST['email'] ?? ''), FILTER_SANITIZE_EMAIL);
$phone     = sanitize($_POST['phone']     ?? '');
$buildings = sanitize($_POST['buildings'] ?? '');
$livestock = sanitize($_POST['livestock'] ?? '');
$message   = sanitize($_POST['message']   ?? '');

if (!$firstName || !$lastName || !$phone) {
    jsonError('Champs obligatoires manquants.');
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    jsonError('Adresse email invalide.');
}

$fullName = "$firstName $lastName";
$date     = date('d/m/Y à H:i');

/* ── 1. Email de notification interne ────────────────────── */

$toInternal      = 'contact@homabot.com';
$fromAddress     = 'contact@dataferme.com';
$subjectInternal = encodeSubject("🐔 Nouvelle demande de démo Dataferme — $fullName");

$bodyInternal  = "Nouvelle demande de démonstration Dataferme\n";
$bodyInternal .= str_repeat('─', 50) . "\n\n";
$bodyInternal .= "Prénom          : $firstName\n";
$bodyInternal .= "Nom             : $lastName\n";
$bodyInternal .= "Email           : $email\n";
$bodyInternal .= "Téléphone       : $phone\n";
$bodyInternal .= "Nb bâtiments    : " . ($buildings ?: 'Non renseigné') . "\n";
$bodyInternal .= "Type d'élevage  : " . ($livestock ?: 'Non renseigné') . "\n";
$bodyInternal .= "\nMessage :\n";
$bodyInternal .= ($message ?: '(aucun message)') . "\n";
$bodyInternal .= "\n" . str_repeat('─', 50) . "\n";
$bodyInternal .= "Soumis le $date via le formulaire Dataferme\n";

$headersInternal  = "From: Dataferme <$fromAddress>\r\n";
$headersInternal .= "Reply-To: $fullName <$email>\r\n";
$headersInternal .= "MIME-Version: 1.0\r\n";
$headersInternal .= "Content-Type: text/plain; charset=UTF-8\r\n";
$headersInternal .= "Content-Transfer-Encoding: 8bit\r\n";

$sentInternal = mail($toInternal, $subjectInternal, $bodyInternal, $headersInternal);

/* ── 2. Email de confirmation à l'éleveur ────────────────── */

$subjectConfirm = encodeSubject("Votre demande de démo Dataferme a bien été reçue");

$bodyConfirm  = "Bonjour $firstName,\n\n";
$bodyConfirm .= "Nous avons bien reçu votre demande de démonstration Dataferme.\n";
$bodyConfirm .= "Notre équipe vous contactera dans les 24h ouvrées pour planifier votre session.\n\n";
$bodyConfirm .= "Voici un récapitulatif de votre demande :\n";
$bodyConfirm .= str_repeat('─', 40) . "\n";
$bodyConfirm .= "Nom             : $fullName\n";
$bodyConfirm .= "Téléphone       : $phone\n";
if ($buildings) $bodyConfirm .= "Nb bâtiments    : $buildings\n";
if ($livestock)  $bodyConfirm .= "Type d'élevage  : $livestock\n";
if ($message)    $bodyConfirm .= "\nMessage         : $message\n";
$bodyConfirm .= str_repeat('─', 40) . "\n\n";
$bodyConfirm .= "En attendant, vous pouvez choisir directement un créneau :\n";
$bodyConfirm .= "→ https://calendly.com/dataferme/demo\n\n";
$bodyConfirm .= "Pour toute question : contact@dataferme.com\n\n";
$bodyConfirm .= "À très bientôt,\n";
$bodyConfirm .= "L'équipe Dataferme\n";

$headersConfirm  = "From: Dataferme <$fromAddress>\r\n";
$headersConfirm .= "Reply-To: Dataferme <$fromAddress>\r\n";
$headersConfirm .= "MIME-Version: 1.0\r\n";
$headersConfirm .= "Content-Type: text/plain; charset=UTF-8\r\n";
$headersConfirm .= "Content-Transfer-Encoding: 8bit\r\n";

$sentConfirm = mail($email, $subjectConfirm, $bodyConfirm, $headersConfirm);

/* ── Réponse JSON ─────────────────────────────────────────── */

if ($sentInternal) {
    echo json_encode(['success' => true]);
} else {
    // L'email de notification a échoué — on remonte l'erreur
    jsonError('Erreur lors de l\'envoi. Veuillez nous contacter directement à contact@dataferme.com');
}
