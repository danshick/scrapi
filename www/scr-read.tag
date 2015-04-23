<group-list>

  <ul>
    <li each="{ g, gobj in groups.list }" >
      <h3>{ g }</h3>
      <ul>
        <li each="{ f, fobj in gobj }" >
          { f } - <a href="../../scrapi/group/{ g }/{ f }" >{ fobj.name + '.' + fobj.ext }</a> - SHA1: { fobj.sha1 }
        </li>
      </ul>
    </li>
  </ul>
  
  <script>
    
    var tag = this;
    
    this.groups = new Groups();
    this.groups.trigger('update');
    
    function Groups(){
      riot.observable(this);
      
      var thisG = this;
      this.list = {};
      this.files = new Files();
      
      this.on('update', function(){
        var client = new XMLHttpRequest();
        client.open("get", "../../scrapi/group", true);
        client.send();
        
        client.onreadystatechange = function(){
          if (client.readyState == 4 && client.status == 200){
            var res = JSON.parse(client.response);
            for( var g in res ){
              thisG.list[res[g]] = {};
              thisG.files.trigger('update', res[g]);
            }
          }
        }
      });
      
      function Files(g){
        riot.observable(this);
        
        this.on('update', function(g){
          var client = new XMLHttpRequest();
          client.open("get", "../../scrapi/group/" + g, true);
          client.send();

          client.onreadystatechange = function(){
            if (client.readyState == 4 && client.status == 200){
              var res = JSON.parse(client.response);
              thisG.list[g] = res;
              tag.update();
            }
          }
        });
      }
      
    }
  
  </script>
  
</group-list>

