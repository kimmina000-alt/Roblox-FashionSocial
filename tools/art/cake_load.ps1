$root = 'D:\Roblox\Roblox-FashionSocial\tools\art'
if (-not ('CakeCut' -as [type])) {
	Add-Type -Path "$root\StlTool.cs", "$root\Qem.cs", "$root\CakeTool.cs", "$root\CakeCut.cs", "$root\CakeKinds.cs" -ReferencedAssemblies System.Drawing, System.Web.Extensions
}
