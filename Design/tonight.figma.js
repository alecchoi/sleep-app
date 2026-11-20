// Initial editable Figma composition, aligned with App/TonightView.swift.
// Execute through the connected Figma Plugin API, not a browser console.
await Promise.all(['Regular','Medium','Semi Bold'].map(style =>
  figma.loadFontAsync({family:'Inter',style})
));
if (figma.currentPage.children.some(n => n.name === 'Tonight / First use / iPhone')) {
  throw new Error('The screen already exists. Update its nodes instead of creating duplicates.');
}

const oldRoots=figma.currentPage.children.filter(n=>['PrimaryButton','BedtimeTimeColumn','TabItem','ProtectionSummary / Setup'].includes(n.name));
for(const node of oldRoots) $fig.get(node.id).remove();
for(const collection of await figma.variables.getLocalVariableCollectionsAsync()) {
 if(['Sleep / Primitives','Sleep / Semantic'].includes(collection.name)) $fig.getVarCollection(collection.id).remove();
}
for(const style of await figma.getLocalTextStylesAsync()) {
 if(style.name.startsWith('Sleep / ')) $fig.getStyle(style.id).remove();
}
const primitive = $fig.varCollection({name:'Sleep / Primitives',modes:['Value']});
const semantic = $fig.varCollection({name:'Sleep / Semantic',modes:['Dark']});
const colors = {};
for (const [name,value] of Object.entries({
  background:'#0C0F19',card:'#171B2A',accent:'#C5BEF6',
  text:'#F1EFF6',secondary:'#AAB0C5',mint:'#A1CFC1'
})) {
  const scopes=['FRAME_FILL','SHAPE_FILL','TEXT_FILL','STROKE_COLOR'];
  const p=primitive.colorVar({name:'palette/'+name,values:{Value:value},scopes});
  colors[name]=semantic.colorVar({
    name:'color/'+name,values:{Dark:p},scopes,
    codeSyntax:{iOS:'SleepTheme.'+(name==='accent'?'lavender':name)}
  });
}
const spaces={}, radii={};
for(const n of [8,12,16,20,24,28]) {
  const p=primitive.numVar({name:'spacing/'+n,values:{Value:n},scopes:['GAP']});
  spaces[n]=semantic.numVar({name:'spacing/'+n,values:{Dark:p},scopes:['GAP']});
}
for(const n of [16,18,22]) {
  const p=primitive.numVar({name:'radius/'+n,values:{Value:n},scopes:['CORNER_RADIUS']});
  radii[n]=semantic.numVar({name:'radius/'+n,values:{Dark:p},scopes:['CORNER_RADIUS']});
}
const fill=name=>[{type:'SOLID',color:colors[name]}];
const typography={
  display:{size:34,weight:'Regular'},
  headline:{size:17,weight:'Semi Bold'},
  body:{size:17,weight:'Regular'},
  footnote:{size:13,weight:'Regular'},
  caption:{size:11,weight:'Medium'}
};
const styles={};
for(const [name,value] of Object.entries(typography)) {
  styles[name]=$fig.textStyle({
    name:'Sleep / '+name,fontName:{family:'Inter',style:value.weight},
    fontSize:value.size,lineHeight:{unit:'PERCENT',value:name==='display'?116:135}
  });
}
const text=(characters,type='body',color='text',options={})=>$fig.text({
  characters,textStyle:styles[type],fills:fill(color),...options
});

const sourceSVGs={"moon":"<svg\n  xmlns=\"http://www.w3.org/2000/svg\"\n  width=\"24\"\n  height=\"24\"\n  viewBox=\"0 0 24 24\"\n  fill=\"none\"\n  stroke=\"currentColor\"\n  stroke-width=\"2\"\n  stroke-linecap=\"round\"\n  stroke-linejoin=\"round\"\n>\n  <path d=\"M20.985 12.486a9 9 0 1 1-9.473-9.472c.405-.022.617.46.402.803a6 6 0 0 0 8.268 8.268c.344-.215.825-.004.803.401\" />\n</svg>\n","sun":"<svg\n  xmlns=\"http://www.w3.org/2000/svg\"\n  width=\"24\"\n  height=\"24\"\n  viewBox=\"0 0 24 24\"\n  fill=\"none\"\n  stroke=\"currentColor\"\n  stroke-width=\"2\"\n  stroke-linecap=\"round\"\n  stroke-linejoin=\"round\"\n>\n  <circle cx=\"12\" cy=\"12\" r=\"4\" />\n  <path d=\"M12 2v2\" />\n  <path d=\"M12 20v2\" />\n  <path d=\"m4.93 4.93 1.41 1.41\" />\n  <path d=\"m17.66 17.66 1.41 1.41\" />\n  <path d=\"M2 12h2\" />\n  <path d=\"M20 12h2\" />\n  <path d=\"m6.34 17.66-1.41 1.41\" />\n  <path d=\"m19.07 4.93-1.41 1.41\" />\n</svg>\n","sliders-horizontal":"<svg\n  xmlns=\"http://www.w3.org/2000/svg\"\n  width=\"24\"\n  height=\"24\"\n  viewBox=\"0 0 24 24\"\n  fill=\"none\"\n  stroke=\"currentColor\"\n  stroke-width=\"2\"\n  stroke-linecap=\"round\"\n  stroke-linejoin=\"round\"\n>\n  <path d=\"M10 5H3\" />\n  <path d=\"M12 19H3\" />\n  <path d=\"M14 3v4\" />\n  <path d=\"M16 17v4\" />\n  <path d=\"M21 12h-9\" />\n  <path d=\"M21 19h-5\" />\n  <path d=\"M21 5h-7\" />\n  <path d=\"M8 10v4\" />\n  <path d=\"M8 12H3\" />\n</svg>\n","shield":"<svg\n  xmlns=\"http://www.w3.org/2000/svg\"\n  width=\"24\"\n  height=\"24\"\n  viewBox=\"0 0 24 24\"\n  fill=\"none\"\n  stroke=\"currentColor\"\n  stroke-width=\"2\"\n  stroke-linecap=\"round\"\n  stroke-linejoin=\"round\"\n>\n  <path d=\"M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z\" />\n</svg>\n","book":"<svg\n  xmlns=\"http://www.w3.org/2000/svg\"\n  width=\"24\"\n  height=\"24\"\n  viewBox=\"0 0 24 24\"\n  fill=\"none\"\n  stroke=\"currentColor\"\n  stroke-width=\"2\"\n  stroke-linecap=\"round\"\n  stroke-linejoin=\"round\"\n>\n  <path d=\"M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20\" />\n</svg>\n","chevron-right":"<svg\n  xmlns=\"http://www.w3.org/2000/svg\"\n  width=\"24\"\n  height=\"24\"\n  viewBox=\"0 0 24 24\"\n  fill=\"none\"\n  stroke=\"currentColor\"\n  stroke-width=\"2\"\n  stroke-linecap=\"round\"\n  stroke-linejoin=\"round\"\n>\n  <path d=\"m9 18 6-6-6-6\" />\n</svg>\n"};
const sourceNames={'moon':'moon','moon.stars':'moon','moon.fill':'moon','sun.max':'sun','slider.horizontal.3':'sliders-horizontal','shield':'shield','book.closed':'book','chevron.right':'chevron-right'};
const literalColors={background:'#0C0F19',accent:'#C5BEF6',secondary:'#AAB0C5'};
const icons=new Map();
const iconSpecs=[['moon.stars',18,'background'],['moon',21,'accent'],['sun.max',21,'accent'],['slider.horizontal.3',21,'accent'],['shield',21,'accent'],['chevron.right',12,'secondary'],['moon.fill',60,'accent'],['book.closed',24,'accent']];
for(const [name,size,color] of iconSpecs){
 let svg=sourceSVGs[sourceNames[name]].replace('width="24"','width="'+size+'"').replace('height="24"','height="'+size+'"').replaceAll('currentColor',literalColors[color]);
 if(name==='moon.fill') svg=svg.replace('fill="none"','fill="'+literalColors[color]+'"').replace('stroke="'+literalColors[color]+'"','stroke="none"');
 const component=$fig.svgComponent(svg,{name:'Icon / '+name+' / '+color,width:size,height:size,x:950,y:icons.size*90});
 icons.set(name+'-'+size+'-'+color,{component,color,filled:name==='moon.fill'});
}
await $fig.done();
for(const {component,color,filled} of icons.values()){
 for(const vector of component.node.findAll(n=>n.type==='VECTOR')){
  $fig.get(vector.id).set(filled?{fills:fill(color)}:{strokes:fill(color)});
 }
}
const iconComponent=(name,size=20,color='accent')=>icons.get(name+'-'+size+'-'+color).component;
const sf=(name,size=20,color='accent')=>$fig.instance(iconComponent(name,size,color));
const button=$fig.component({
  name:'PrimaryButton',x:520,y:0,width:345,height:52,layoutMode:'HORIZONTAL',
  primaryAxisAlignItems:'CENTER',counterAxisAlignItems:'CENTER',
  itemSpacing:spaces[12],paddingLeft:spaces[16],paddingRight:spaces[16],
  cornerRadius:radii[18],fills:fill('accent')
},[sf('moon.stars',18,'background'),text('Begin wind-down','headline','background').textProp('Label')]);
const timeColumn=$fig.component({
  name:'BedtimeTimeColumn',x:520,y:90,layoutMode:'VERTICAL',
  itemSpacing:spaces[12],fills:[]
},[
  text('TRY SLEEPING AT','caption','secondary').textProp('Caption'),
  text('11:00 PM','headline').textProp('Time')
]);
const tab=$fig.component({
  name:'TabItem',x:520,y:210,width:115,height:62,layoutMode:'VERTICAL',
  primaryAxisAlignItems:'CENTER',counterAxisAlignItems:'CENTER',itemSpacing:spaces[8],fills:[]
},[
  sf('moon',21).instanceSwapProp('Icon'),
  text('Tonight','caption','accent').textProp('Label')
]);
const protection=$fig.component({
  name:'ProtectionSummary / Setup',x:520,y:310,width:345,layoutMode:'HORIZONTAL',
  itemSpacing:spaces[12],paddingLeft:spaces[16],paddingRight:spaces[16],
  paddingTop:spaces[16],paddingBottom:spaces[16],counterAxisAlignItems:'CENTER',
  cornerRadius:radii[18],fills:fill('card')
},[
  sf('shield',21),
  $fig.autoLayout({
    layoutMode:'VERTICAL',layoutSizingHorizontal:'FILL',itemSpacing:spaces[8],fills:[]
  },[
    text('Set up app protection','headline').textProp('Title'),
    text('Choose which apps to leave until morning.','footnote','secondary',{
      layoutSizingHorizontal:'FILL',textAutoResize:'HEIGHT'
    }).textProp('Detail')
  ]),
  sf('chevron.right',12,'secondary')
]);
const moon=$fig.frame({name:'MoonIllustration / Compact',width:345,height:138,fills:[]},[
  $fig.ellipse({
    name:'Outer orbit',x:98,y:-5,width:149,height:149,fills:[],
    strokes:fill('accent'),strokeWeight:1,opacity:0.07
  }),
  $fig.ellipse({
    name:'Inner orbit',x:113,y:10,width:119,height:119,fills:[],
    strokes:fill('accent'),strokeWeight:1,opacity:0.12
  }),
  sf('moon.fill',60).set({x:142,y:39,rotation:18}),
  $fig.ellipse({name:'Small star',x:236,y:37,width:2,height:2,fills:fill('accent'),opacity:0.7})
]);
const planCard=$fig.autoLayout({
  name:'Bedtime plan',layoutMode:'VERTICAL',layoutSizingHorizontal:'FILL',
  itemSpacing:spaces[16],paddingLeft:spaces[20],paddingRight:spaces[20],
  paddingTop:spaces[20],paddingBottom:spaces[20],cornerRadius:radii[22],fills:fill('card')
},[
  $fig.autoLayout({
    layoutMode:'HORIZONTAL',layoutSizingHorizontal:'FILL',primaryAxisAlignItems:'SPACE_BETWEEN',fills:[]
  },[
    $fig.instance(timeColumn),
    $fig.instance(timeColumn,{props:{Caption:'WAKE UP AT',Time:'7:00 AM'}})
  ]),
  $fig.rectangle({
    name:'Divider',height:1,layoutSizingHorizontal:'FILL',fills:fill('secondary'),opacity:0.15
  }),
  $fig.autoLayout({
    layoutMode:'HORIZONTAL',layoutSizingHorizontal:'FILL',
    primaryAxisAlignItems:'SPACE_BETWEEN',counterAxisAlignItems:'CENTER',fills:[]
  },[
    text('Wind-down starts at 10:30 PM','footnote','secondary'),sf('chevron.right',12,'secondary')
  ])
]);
const body=$fig.frame({
  name:'Tonight / Scroll content',layoutMode:'VERTICAL',width:393,height:664,
  paddingLeft:spaces[24],paddingRight:spaces[24],paddingTop:spaces[24],
  paddingBottom:spaces[24],itemSpacing:spaces[20],fills:[],clipsContent:true,overflowDirection:'VERTICAL'
},[
  text('SLEEP APP','caption','secondary'),
  text('The day\ncan wait.','display'),
  text('A softer landing for your evening.','body','secondary'),
  moon,planCard,$fig.instance(protection,{layoutSizingHorizontal:'FILL'}),
  text('YOUR QUIET MOMENT','caption','secondary'),
  $fig.autoLayout({name:'Quiet activity',layoutMode:'HORIZONTAL',itemSpacing:spaces[16],fills:[]},[
    sf('book.closed',24),
    $fig.autoLayout({layoutMode:'VERTICAL',itemSpacing:spaces[8],fills:[]},[
      text('The harbor at dusk','headline'),text('A short, quiet reading','footnote','secondary')
    ])
  ])
]);
const footer=$fig.autoLayout({
  name:'Pinned wind-down action',layoutMode:'VERTICAL',width:393,height:104,
  paddingLeft:spaces[24],paddingRight:spaces[24],paddingTop:spaces[12],paddingBottom:spaces[12],
  itemSpacing:spaces[12],counterAxisAlignItems:'CENTER',fills:fill('background')
},[
  $fig.instance(button,{layoutSizingHorizontal:'FILL'}),
  text('You can stop whenever you feel ready.','caption','secondary')
]);
const tabs=$fig.autoLayout({
  name:'TabView',layoutMode:'HORIZONTAL',width:393,height:84,
  paddingLeft:spaces[24],paddingRight:spaces[24],counterAxisAlignItems:'CENTER',fills:fill('background')
},[
  $fig.instance(tab),
  $fig.instance(tab,{opacity:0.55,props:{Label:'Mornings',Icon:iconComponent('sun.max',21).node.id}}),
  $fig.instance(tab,{opacity:0.55,props:{Label:'Settings',Icon:iconComponent('slider.horizontal.3',21).node.id}})
]);
const screen=$fig.frame({
  name:'Tonight / First use / iPhone',width:393,height:852,layoutMode:'VERTICAL',
  itemSpacing:0,fills:fill('background'),clipsContent:true
},[body,footer,tabs]);
await $fig.done();
const fontsUsed=[...new Set(screen.node.findAll(n=>n.type==='TEXT').map(n=>n.fontName.family))];
if(fontsUsed.some(f=>f!=='Inter')) throw new Error('Unexpected font family: '+fontsUsed.join(','));
screen.screenshot({scale:1});
return {
  screenId:screen.node.id,
  componentIds:[button.node.id,timeColumn.node.id,tab.node.id,protection.node.id],
  fontFamilies:fontsUsed,editableTextNodes:screen.node.findAll(n=>n.type==='TEXT').length
};
