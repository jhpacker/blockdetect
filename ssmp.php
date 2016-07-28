<?php

  /* Server-side measurement protocol proxy for experiment described here:
   * https://www.quantable.com/analytics/how-many-users-block-google-analytics/   
   *
   * script is called from frontend (e.g. frontend.html) and uses GA measurement protocol to
   * make calls to GA, then returns GA tracker code to frontend for execution
   * 
   * (c)2016 Quantable LLC
   */


// depends on: https://github.com/analytics-pros/universal-analytics-php 
require('universal-analytics.php');

// your GA profile id here:
$UA = 'UA-XXX-1';

// don't create hashes for user ids in the univeral-analytics.php library
define('ANALYTICS_HASH_IDS', false);

// bail out if it's a UA that causes issues
if (preg_match('/googleweblight/', $_SERVER['HTTP_USER_AGENT'])){
    exit;
}

header("Content-Type: application/javascript");

$cid = null;
$t = new Tracker(
    $UA,
    $cid,  //cid
    $_REQUEST['browserid'], // uid
    false // debug
);

// grab browser info that we just sent to GA via JS (paramters & headers)
// screenColors (sd)
// screenResolution (sr)
// viewportSize (vp)
// userAgent

$t->setUserAgent($_SERVER['HTTP_USER_AGENT']);

$t->set('dimension1', 'serverside');
$t->set('dimension2', $_REQUEST['browserid']);

$hostname = parse_url($_SERVER['HTTP_REFERER'], PHP_URL_HOST);

$uip = get_ip_address();

$t->send('event', 
         array(
             'eventCategory' => 'block test',
             'eventAction' => 'visit',
             'eventLabel' => 'server',
             'eventValue' => '1',
             'screenResolution' => $_REQUEST['screenResolution'],
             'viewportSize' => $_REQUEST['viewportSize'],
             'screenColors' => $_REQUEST['screenColors'],
             'encoding' => 'UTF-8',
             'hostname' => $hostname,
             'uip' => $uip,
             'referrer' => $_REQUEST['referrer']
         )
);

?>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

  ga('create', '<?php echo $UA; ?>', 'auto', 'ga2');
  ga('ga2.set', 'dimension1', 'clientside');
  ga('ga2.set', 'dimension2', '<?php echo $_REQUEST['browserid']; ?>');
  ga('ga2.set', 'userId', '<?php echo $_REQUEST['browserid']; ?>');
  ga('ga2.set', 'transport', 'beacon');

  ga('ga2.send', {
        hitType: 'event',
              eventCategory: 'block test',
              eventAction: 'visit',
              eventLabel: 'client',
              eventValue: '1'
            });
<?
function get_ip_address(){
    //http://stackoverflow.com/questions/1634782/what-is-the-most-accurate-way-to-retrieve-a-users-correct-ip-address-in-php
    foreach (array('HTTP_CLIENT_IP', 'HTTP_X_FORWARDED_FOR', 'HTTP_X_FORWARDED', 'HTTP_X_CLUSTER_CLIENT_IP', 'HTTP_FORWARDED_FOR', 'HTTP_FORWARDED', 'REMOTE_ADDR') as $key){
        if (array_key_exists($key, $_SERVER) === true){
            foreach (explode(',', $_SERVER[$key]) as $ip){
                $ip = trim($ip); // just to be safe

                if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE) !== false){
                    return $ip;
                }
            }
        }
    }
}
?>