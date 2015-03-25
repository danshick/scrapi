<?php

require_once('./vendor/autoload.php');
require('secret.php');
$router = new \Zaphpa\Router();

class SCRController {
  
  private function checkJWT(){
    
    $allheaders = getallheaders();
    if( !isset($allheaders["Authorization"])){
      return FALSE;
    }
	  $jwtHeader = $allheaders["Authorization"];
    $now = time();
    try{
      global $key;
      $decoded = (array) JWT::decode($jwtHeader, $key);
    }
    catch(Exception $e){
      return FALSE;
    }
    $iss = $decoded['iss'];
    $usr = $decoded['usr'];
    $iat = $decoded['iat'];
    $exp = $decoded['exp'];
    
    if($exp < $now){
      return false;
    }
    if( strcmp($usr, "admin") != 0 ){
      return false;
    }
    if( strcmp($iss, "http://summercampreading.org") != 0 ){
      return false;
    }
    if($iat > $now){
      return false;
    }
    
    return true;
    
  }
  
  private function issueJWT(){
    
    $now = time();
    
    $token = array(
      "iss" => "http://summercampreading.org",
      "usr" => "admin",
      "iat" => $now,
      "exp" => $now + (24 * 60 * 60)
    );
    global $key;
    return JWT::encode($token, $key);
  
  }
  
  private function getListing(){
    
    //get listing from catalogue file if it exists and is not empty
    $jsonname = getcwd() . "/files.json";
    if( file_exists($jsonname) && filesize($jsonname) > 0 ){
      $ptr = fopen( $jsonname, 'r');
      $listing = fread($ptr, filesize($jsonname));
      fclose($ptr);
      $listing = json_decode($listing, true);
    }
    
    //set default listing value if it is null 
    if(!isset($listing)){
      $listing = array();
    }
    
    return $listing;
    
  }
  
  private function setListing($listing){
    
    $jsonname = getcwd() . "/files.json";
    $ptr = fopen( $jsonname, 'w');
    fwrite($ptr, json_encode($listing));
    fclose($ptr);
    
  }
  
  public function login($req, $res) {
    
    $res->setFormat("json");
    
    $data = json_decode(array_pop($req->data), true);
    $user = $data["username"];
    $pass = $data["password"];
    
    if(strcmp($user, "admin") != 0 || strcmp($pass, "test") != 0){
      $res->add(json_encode(array("error" => "Not authorized")));
      $res->send(403);
      return ;
    }
    
    $res->add($this->issueJWT());
    $res->send(200);
    
  }
  
  public function getGroups($req, $res) {
    
    //check auth
    if($this->checkJWT() == FALSE){
      $res->setFormat("json");
      $res->add(json_encode(array("error" => "Not authorized")));
      $res->send(403);
      return ;
    }
    
    //get listing from catalogue file
    $listing = $this->getListing();
    
    $res->setFormat("json");
    $res->add(json_encode(array_keys($listing)));
    $res->send(200);
	
  }
  
  public function getGroup($req, $res) {
    
    //check auth
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
    
    //set groupDetail based on group existence
    if( isset($listing[$gname]) ){
      $groupDetail = $listing[$gname];
    }
    else{
      $res->setFormat("json");
      $res->add(json_encode(array("error" => "Group doesn't exist")));
      $res->send(200);
    }
    
    $res->setFormat("json");
    $res->add(json_encode($groupDetail));
    $res->send(200);
	
  }
  
  public function getFile($req, $res) {
    
    //check auth
    //if($this->checkJWT() == FALSE){
    //  $res->setFormat("json");
    //  $res->add(json_encode(array("error" => "Not authorized")));
    //  $res->send(403);
    //  return ;
    //}
    
    //get group and file title from params
    $gname = $req->params["gname"];
    $ftitle = $req->params["ftitle"];
    
    //get listing from catalogue file
    $listing = $this->getListing();
    
    //set groupDetail based on group existence
    if( isset($listing[$gname]) ){
      $groupDetail = $listing[$gname];
    }
    else{
      $res->setFormat("json");
      $res->add(json_encode(array("error" => "Group doesn't exist")));
      $res->send(404);
      return ;
    }
    
    //set fileDetail based on file existence
    if( isset($groupDetail[$ftitle]) ){
      $fileDetail = $groupDetail[$ftitle];
    }
    else{
      $res->setFormat("json");
      $res->add(json_encode(array("error" => "File doesn't exist")));
      $res->send(404);
      return ;
    }
    
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
  
  public function uploadFile($req, $res){
    
    //check auth
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
    
    //write file
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
    //'fid'      => \Zaphpa\Template::regex('(?P<%s>[a-z0-9]{40})') // enforced sha1
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

try {
  $router->route();
} catch (\Zaphpa\Exceptions\InvalidPathException $ex) {      
  header("Content-Type: application/json;", TRUE, 404);
  $out = array("error" => "API endpoint not found");        
  die(json_encode($out));
}

?>