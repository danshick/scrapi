<group-list>
  
  <ul>
    <li each="{ g, gobj in groups.list }" >
      <h3>{ g }</h3>
      <ul>
        <li each="{ f, fobj in gobj }" >
          {f} - <a href="../../scrapi/group/{g}/{f}" >{fobj.name + '.' + fobj.ext}</a> - SHA1: {fobj.sha1}
        </li>
      </ul>
    </li>
  </ul>
  
  <script>
  groups.update();
  
  var tag = this;
  files.on('update', function() {
    tag.update();
  });
  
  </script>
  
</group-list>

var login = function(){
  
  var client = new XMLHttpRequest();
  client.open("post", "../../scrapi/login", true);
  client.send(JSON.stringify({username:"admin", password:"test"}));

  client.onreadystatechange = function(){
    if (client.readyState == 4 && client.status == 200){
      var res = JSON.parse(client.response);
      var tomorrow = new Date(Date.now() + 24*60*60 );
      localStorage.setItem("auth-token", res["auth-token"] );
      document.cookie="Authorization="+ res["auth-token"] +"; expires="+tomorrow.toUTCString()+"; path=/scrapi";
      console.log(document.cookie);
    }
  } 
}
login();

var auth = riot.observable();
var groups = riot.observable();
groups.update = function(){
  groups.list = {};
  
  var client = new XMLHttpRequest();
  client.open("get", "../../scrapi/group", true);
  client.setRequestHeader("Authorization", localStorage.getItem("auth-token"));
  client.send();

  client.onreadystatechange = function(){
    if (client.readyState == 4 && client.status == 200){
      var res = JSON.parse(client.response);
      for( var g in res ){
        groups.list[res[g]] = {};
        files.update(res[g]);
      }
      groups.trigger('update');
    }
  }
}

var files = riot.observable();
files.update = function(g){
    
    var client = new XMLHttpRequest();
    client.open("get", "../../scrapi/group/" + g, true);
    client.setRequestHeader("Authorization", localStorage.getItem("auth-token"));
    client.send();

    client.onreadystatechange = function(){
      if (client.readyState == 4 && client.status == 200){
        var res = JSON.parse(client.response);
        groups.list[g] = res;
        files.trigger('update');
      }
    }
  
}