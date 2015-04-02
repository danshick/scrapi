<?php

//bring in php-jwt and zaphpa
require_once('./vendor/autoload.php');

//separate storage for secret $key for JWT
require('secret.php');

//instantiate zaphpa router
$router = new \Zaphpa\Router();

//set up class to contain api methods
class SCRController {
  
  //checks Authorization header for valid auth jwt
  private function checkJWT(){
    
    //check for Authorization header
    //capture Authorization header and decode
    $allheaders = getallheaders();
    if( !isset($allheaders["Authorization"])){
      if(!isset($_COOKIE["Authorization"])){
        return FALSE;
      }
      $jwtHeader = $_COOKIE["Authorization"];
    }
    else{
      $jwtHeader = $allheaders["Authorization"];
    }
    
    $now = time();
    try{
      //fetch our key from secret.php and decode
      global $key;
      $decoded = (array) JWT::decode($jwtHeader, $key);
    }
    catch(Exception $e){
      //invalid sig or all together bad token
      return FALSE;
    }
    
    //pull out jwt components
    $iss = $decoded['iss'];
    $usr = $decoded['usr'];
    $iat = $decoded['iat'];
    $exp = $decoded['exp'];
    $alg = JWT::jsonDecode(JWT::urlsafeB64Decode(explode('.', $jwtHeader)[0]))->alg;
    //check that the algorithm is sane

    if( strcmp($alg, "HS256") != 0 ){
      return false;
    }

    //check that it is not expired
    if($exp < $now){
      return false;
    }
    
    //check username (currently hardcoded)
    if( strcmp($usr, "admin") != 0 ){
      return false;
    }
    
    //check issuer (currently hardcoded)
    if( strcmp($iss, "http://summercampreading.org") != 0 ){
      return false;
    }
    
    //check issued at time isn't in the future
    if($iat > $now){
      return false;
    }
    
    //we're all good
    return true;
    
  }
  
  //create new auth jwt once username and passwd are verified
  private function issueJWT(){
    
    //get the unix time
    $now = time();
    
    //define an array to hold our token components
    $token = array(
      "iss" => "http://summercampreading.org",
      "usr" => "admin",
      "iat" => $now,
      "exp" => $now + (24 * 60 * 60)
    );
    
    //fetch our key from secret.php and return encoded jwt
    global $key;
    return JWT::encode($token, $key);
  
  }
  
  //retrieve full file listing as an array
  private function getListing(){
    
    //get listing from catalogue file if it exists and is not empty
    //path currently hardcoded
    $jsonname = getcwd() . "/files.json";
    if( file_exists($jsonname) && filesize($jsonname) > 0 ){
      $ptr = fopen( $jsonname, 'r');
      $listing = fread($ptr, filesize($jsonname));
      fclose($ptr);
      $listing = json_decode($listing, true);
    }
    
    //set empty array listing value if it is null
    //this will catch if file doesn't exist, file is empty, or file is formatted incorrectly
    if(!isset($listing)){
      $listing = array();
    }
    
    return $listing;
    
  }
  
  //write full file listing array to file
  private function setListing($listing){
    
    //write listing to catalogue file
    //path currently hardcoded
    $jsonname = getcwd() . "/files.json";
    $ptr = fopen( $jsonname, 'w');
    fwrite($ptr, json_encode($listing));
    fclose($ptr);
    
  }
  
  //check credentials and issue a jwt auth token
  public function login($req, $res) {
    
    //responding in json
    $res->setFormat("json");
    
    //grabbing username and password from the request
    $data = json_decode(array_pop($req->data), true);
    $user = $data["username"];
    $pass = $data["password"];
    
    //hardcoded username and password validation
    //403 if wrong
    if(strcmp($user, "admin") != 0 || strcmp($pass, "test") != 0){
      $res->add(json_encode(array("error" => "Not authorized")));
      $res->send(403);
      return ;
    }
    
    //our auth was good so we issue a token and respond 200
    $res->add('{"auth-token": "' . $this->issueJWT() . '" }');
    $res->send(200);
    
  }
  
  //return all file groups as per the listing file
  public function getGroups($req, $res) {
    
    //check auth, reply 403 and get out if invalid
    if($this->checkJWT() == FALSE){
      $res->setFormat("json");
      $res->add(json_encode(array("error" => "Not authorized")));
      $res->send(403);
      return ;
    }
    
    //get listing from catalogue file
    $listing = $this->getListing();
    
    //reply 200 with the listing
    $res->setFormat("json");
    $res->add(json_encode(array_keys($listing)));
    $res->send(200);
	
  }
  
  //return details of a file group as per the listing file
  public function getGroup($req, $res) {
    
    //check auth, reply 403 and get out if invalid
    if($this->checkJWT() == FALSE){
      $res->setFormat("json");
      $res->add(json_encode(array("error" => "Not authorized")));
      $res->send(403);
      return ;
    }
    
    //get group from params
    $gname = $req->params["gname"];
    
    //get listing from catalogue file
    $listing = $this->getListing();
    
    //set groupDetail if group exists
    if( isset($listing[$gname]) ){
      $groupDetail = $listing[$gname];
    }
    //reply 404 with error about non-existent group and get out
    else{
      $res->setFormat("json");
      $res->add(json_encode(array("error" => "Group doesn't exist")));
      $res->send(404);
      return ;
    }
    
    //reply 200 with group information
    $res->setFormat("json");
    $res->add(json_encode($groupDetail));
    $res->send(200);
	
  }
  
  //return a file as per the listing file
  public function getFile($req, $res) {
    
    //check auth, reply 403 and get out if invalid
    if($this->checkJWT() == FALSE){
      $res->setFormat("json");
      $res->add(json_encode(array("error" => "Not authorized")));
      $res->send(403);
      return ;
    }
    
    //get group and file title from params
    $gname = $req->params["gname"];
    $ftitle = $req->params["ftitle"];
    
    //get listing from catalogue file
    $listing = $this->getListing();
    
    //set groupDetail if group exists
    if( isset($listing[$gname]) ){
      $groupDetail = $listing[$gname];
    }
    //reply 404 with error about non-existent group and get out
    else{
      $res->setFormat("json");
      $res->add(json_encode(array("error" => "Group doesn't exist")));
      $res->send(404);
      return ;
    }
    
    //set fileDetail if file exists
    if( isset($groupDetail[$ftitle]) ){
      $fileDetail = $groupDetail[$ftitle];
    }
    //reply 404 with error about non-existent file and get out
    else{
      $res->setFormat("json");
      $res->add(json_encode(array("error" => "File doesn't exist")));
      $res->send(404);
      return ;
    }
    
    //reply with 200, the file, and set a ton of headers to ensure a file download dialog
    $res->setFormat('application/octet-stream');
    $res->addHeader('Content-Description', 'File Transfer');
    $res->addHeader('Content-Disposition', 'attachment; filename='.$fileDetail["name"].'.'.$fileDetail["ext"]);
    $res->addHeader('Expires', '0');
    $res->addHeader('Cache-Control', 'must-revalidate');
    $res->addHeader('Pragma', 'public');
    $res->addHeader('Content-Length', filesize("files/".$fileDetail["sha1"].'.'.$fileDetail["ext"]));
    $res->add(file_get_contents("files/".$fileDetail["sha1"].'.'.$fileDetail["ext"]));
    $res->send(200);
    
    return ;
  }
  
  //upload a file and add it to the listing file
  public function uploadFile($req, $res){
    
    //check auth, reply 403 and get out if invalid
    if($this->checkJWT() == FALSE){
      $res->setFormat("json");
      $res->add(json_encode(array("error" => "Not authorized")));
      $res->send(403);
      return ;
    }
    
    //get group from params
    $gname = $req->params["gname"];
    
    //get file, file details, and sanitize filename
    $data = json_decode(array_pop($req->data), true);
    $fdata = base64_decode($data["file"]);
    $fsha1 = sha1($fdata);
    $ftitle = preg_replace("/[^a-zA-Z0-9 ]+/", "", urldecode($data["title"]));
    $ftitle = preg_replace("/[ ]+/", "_", $ftitle);
    $fname = preg_replace("/[^a-zA-Z0-9 ]+/", "", urldecode($data["name"]));
    $fext = preg_replace("/[^a-zA-Z0-9]+/", "", urldecode($data["extension"]));
    
    //error if name, extension, or title are invalid
    if(empty($fname) || empty($fext) || empty($ftitle)){
      $res->setFormat("json");
      $res->add(json_encode(array("error" => "File name, extension, and title must be valid")));
      $res->send(404);
      return ;
    }
    
    //get listing from catalogue file
    $listing = $this->getListing();
    
    //create group in the listing if it doesn't exist
    if( !isset($listing[$gname]) ){
      $listing[$gname] = array();
    }
    
    //add entry to listing
    $listing[$gname][$ftitle] = array("name" => $fname, "sha1" => $fsha1, "ext" => $fext);
    
    //write listings back to catalogue
    $this->setListing($listing);
    
    //write file to hardcoded location
    $ptr = fopen( getcwd() . "/files/" . $fsha1 . "." . $fext, 'wb');
    fwrite($ptr, $fdata);
    fclose($ptr);
    
    //respond with file details
    $res->setFormat("json");
    $res->add(json_encode(array("status"=>"okay", "title"=>$ftitle, "name"=>$fname, "ext"=> $fext, "sha1"=>$fsha1)));
    $res->send(200);
    
  }
    
}

//router for returning list of all groups
$router->addRoute(array(
  'path'     => '/scrapi/group',
  'get'      => array('SCRController', 'getGroups'),
));

//router for returning a group's file listing
$router->addRoute(array(
  'path'     => '/scrapi/group/{gname}',
  'handlers' => array(
    'gname'         => \Zaphpa\Constants::PATTERN_ALPHA, //enforced alphanumeric
  ),
  'get'      => array('SCRController', 'getGroup'),
));

//router for returning a group's file
$router->addRoute(array(
  'path'     => '/scrapi/group/{gname}/{ftitle}',
  'handlers' => array(
    'gname'    => \Zaphpa\Constants::PATTERN_ALPHA, //enforced alphanumeric
    'ftitle'   => \Zaphpa\Constants::PATTERN_ALPHA, //enforced alphanumeric
  ),
  'get'      => array('SCRController', 'getFile'),
));

//router for uploading a file to a group
$router->addRoute(array(
  'path'     => '/scrapi/group/{gname}/upload',
  'handlers' => array(
    'gname'         => \Zaphpa\Constants::PATTERN_ALPHA, //enforced alphanumeric
  ),
  'post'      => array('SCRController', 'uploadFile'),
));

//router for logging in
$router->addRoute(array(
  'path'     => '/scrapi/login',
  'post'      => array('SCRController', 'login'),
));

//try to route request but kick a 404 if the path doesn't exist
try {
  $router->route();
} catch (\Zaphpa\Exceptions\InvalidPathException $ex) {      
  header("Content-Type: application/json;", TRUE, 404);
  $out = array("error" => "API endpoint not found");        
  die(json_encode($out));
}

?>
