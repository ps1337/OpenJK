in vec2 attr_TexCoord0;
#if defined(USE_LIGHTMAP) || defined(USE_TCGEN)
in vec2 attr_TexCoord1;
#endif
in vec4 attr_Color;

in vec3 attr_Position;
in vec3 attr_Normal;
#if defined(USE_VERT_TANGENT_SPACE)
in vec4 attr_Tangent;
#endif

#if defined(USE_VERTEX_ANIMATION)
in vec3 attr_Position2;
in vec3 attr_Normal2;
  #if defined(USE_VERT_TANGENT_SPACE)
in vec4 attr_Tangent2;
  #endif
#elif defined(USE_SKELETAL_ANIMATION)
in vec4 attr_BoneIndexes;
in vec4 attr_BoneWeights;
#endif

#if defined(USE_LIGHT) && !defined(USE_LIGHT_VECTOR)
in vec3 attr_LightDirection;
#endif

#if defined(USE_DELUXEMAP)
uniform vec4   u_EnableTextures; // x = normal, y = deluxe, z = specular, w = cube
#endif

#if defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
uniform vec3 u_ViewOrigin;
#endif

#if defined(USE_TCGEN)
uniform int u_TCGen0;
uniform vec3 u_TCGen0Vector0;
uniform vec3 u_TCGen0Vector1;
uniform vec3 u_LocalViewOrigin;
#endif

#if defined(USE_TCMOD)
uniform vec4 u_DiffuseTexMatrix;
uniform vec4 u_DiffuseTexOffTurb;
#endif

uniform mat4 u_ModelViewProjectionMatrix;
uniform vec4 u_BaseColor;
uniform vec4 u_VertColor;

#if defined(USE_MODELMATRIX)
uniform mat4 u_ModelMatrix;
#endif

#if defined(USE_VERTEX_ANIMATION)
uniform float u_VertexLerp;
#elif defined(USE_SKELETAL_ANIMATION)
uniform mat4 u_BoneMatrices[20];
#endif

#if defined(USE_LIGHT_VECTOR)
uniform vec4 u_LightOrigin;
uniform float u_LightRadius;
  #if defined(USE_FAST_LIGHT)
uniform vec3 u_DirectedLight;
uniform vec3 u_AmbientLight;
  #endif
#endif

#if defined(USE_PRIMARY_LIGHT) || defined(USE_SHADOWMAP)
uniform vec4 u_PrimaryLightOrigin;
uniform float u_PrimaryLightRadius;
#endif

out vec4 var_TexCoords;
out vec4 var_Color;
out vec3 var_N;

#if defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
  #if defined(USE_VERT_TANGENT_SPACE)
out vec4 var_Normal;
out vec4 var_Tangent;
out vec4 var_Bitangent;
  #else	 
out vec3 var_Normal;
out vec3 var_ViewDir;
  #endif
#endif

#if defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
out vec4 var_LightDir;
#endif

#if defined(USE_PRIMARY_LIGHT) || defined(USE_SHADOWMAP)
out vec4 var_PrimaryLightDir;
#endif

#if defined(USE_TCGEN)
vec2 GenTexCoords(int TCGen, vec3 position, vec3 normal, vec3 TCGenVector0, vec3 TCGenVector1)
{
	vec2 tex = attr_TexCoord0.st;

	if (TCGen >= TCGEN_LIGHTMAP && TCGen <= TCGEN_LIGHTMAP3)
	{
		tex = attr_TexCoord1.st;
	}
	else if (TCGen == TCGEN_ENVIRONMENT_MAPPED)
	{
		vec3 viewer = normalize(u_LocalViewOrigin - position);
		vec2 ref = reflect(viewer, normal).yz;
		tex.s = ref.x * -0.5 + 0.5;
		tex.t = ref.y *  0.5 + 0.5;
	}
	else if (TCGen == TCGEN_VECTOR)
	{
		tex = vec2(dot(position, TCGenVector0), dot(position, TCGenVector1));
	}

	return tex;
}
#endif

#if defined(USE_TCMOD)
vec2 ModTexCoords(vec2 st, vec3 position, vec4 texMatrix, vec4 offTurb)
{
	float amplitude = offTurb.z;
	float phase = offTurb.w * 2.0 * M_PI;
	vec2 st2;
	st2.x = st.x * texMatrix.x + (st.y * texMatrix.z + offTurb.x);
	st2.y = st.x * texMatrix.y + (st.y * texMatrix.w + offTurb.y);

	vec2 offsetPos = vec2(position.x + position.z, position.y);

	vec2 texOffset = sin(offsetPos * (2.0 * M_PI / 1024.0) + vec2(phase));

	return st2 + texOffset * amplitude;	
}
#endif


float CalcLightAttenuation(float point, float normDist)
{
	// zero light at 1.0, approximating q3 style
	// also don't attenuate directional light
	float attenuation = (0.5 * normDist - 1.5) * point + 1.0;

	// clamp attenuation
	#if defined(NO_LIGHT_CLAMP)
	attenuation = max(attenuation, 0.0);
	#else
	attenuation = clamp(attenuation, 0.0, 1.0);
	#endif

	return attenuation;
}


void main()
{
#if defined(USE_VERTEX_ANIMATION)
	vec3 position  = mix(attr_Position,    attr_Position2,    u_VertexLerp);
	vec3 normal    = mix(attr_Normal,      attr_Normal2,      u_VertexLerp);
  #if defined(USE_VERT_TANGENT_SPACE) && defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
	vec3 tangent   = mix(attr_Tangent.xyz, attr_Tangent2.xyz, u_VertexLerp);
  #endif
#elif defined(USE_SKELETAL_ANIMATION)
	vec4 position4 = vec4(0.0);
	vec4 normal4 = vec4(0.0);
	vec4 originalPosition = vec4(attr_Position, 1.0);
	vec4 originalNormal = vec4(attr_Normal - vec3 (0.5), 0.0);
#if defined(USE_VERT_TANGENT_SPACE) && defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
	vec4 tangent4 = vec4(0.0);
	vec4 originalTangent = vec4(attr_Tangent.xyz - vec3(0.5), 0.0);
#endif

	for (int i = 0; i < 4; i++)
	{
		int boneIndex = int(attr_BoneIndexes[i]);

		position4 += (u_BoneMatrices[boneIndex] * originalPosition) * attr_BoneWeights[i];
		normal4 += (u_BoneMatrices[boneIndex] * originalNormal) * attr_BoneWeights[i];
#if defined(USE_VERT_TANGENT_SPACE) && defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
		tangent4 += (u_BoneMatrices[boneIndex] * originalTangent) * attr_BoneWeights[i];
#endif
	}

	vec3 position = position4.xyz;
	vec3 normal = normalize (normal4.xyz);
#if defined(USE_VERT_TANGENT_SPACE) && defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
	vec3 tangent = normalize (tangent4.xyz);
#endif
#else
	vec3 position  = attr_Position;
	vec3 normal    = attr_Normal;
  #if defined(USE_VERT_TANGENT_SPACE) && defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
	vec3 tangent   = attr_Tangent.xyz;
  #endif
#endif

#if !defined(USE_SKELETAL_ANIMATION)
	normal  = normal  * 2.0 - vec3(1.0);
  #if defined(USE_VERT_TANGENT_SPACE) && defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
	tangent = tangent * 2.0 - vec3(1.0);
  #endif
#endif

#if defined(USE_TCGEN)
	vec2 texCoords = GenTexCoords(u_TCGen0, position, normal, u_TCGen0Vector0, u_TCGen0Vector1);
#else
	vec2 texCoords = attr_TexCoord0.st;
#endif

#if defined(USE_TCMOD)
	var_TexCoords.xy = ModTexCoords(texCoords, position, u_DiffuseTexMatrix, u_DiffuseTexOffTurb);
#else
	var_TexCoords.xy = texCoords;
#endif

	gl_Position = u_ModelViewProjectionMatrix * vec4(position, 1.0);

#if defined(USE_MODELMATRIX)
	position  = (u_ModelMatrix * vec4(position, 1.0)).xyz;
	normal    = (u_ModelMatrix * vec4(normal,   0.0)).xyz;
  #if defined(USE_VERT_TANGENT_SPACE) && defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
	tangent   = (u_ModelMatrix * vec4(tangent,  0.0)).xyz;
  #endif
#endif

#if defined(USE_VERT_TANGENT_SPACE) && defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
	vec3 bitangent = cross(normal, tangent) * (attr_Tangent.w * 2.0 - 1.0);
#endif

#if defined(USE_LIGHT_VECTOR)
	vec3 L = u_LightOrigin.xyz - (position * u_LightOrigin.w);
#elif defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
	vec3 L = attr_LightDirection * 2.0 - vec3(1.0);
  #if defined(USE_MODELMATRIX)
	L = (u_ModelMatrix * vec4(L, 0.0)).xyz;
  #endif
#endif

#if defined(USE_LIGHTMAP)
	var_TexCoords.zw = attr_TexCoord1.st;
#endif

	var_Color = u_VertColor * attr_Color + u_BaseColor;

#if defined(USE_LIGHT_VECTOR) && defined(USE_FAST_LIGHT)
	float sqrLightDist = dot(L, L);
	float attenuation = CalcLightAttenuation(u_LightOrigin.w, u_LightRadius * u_LightRadius / sqrLightDist);
	float NL = clamp(dot(normalize(normal), L) / sqrt(sqrLightDist), 0.0, 1.0);

	var_Color.rgb *= u_DirectedLight * (attenuation * NL) + u_AmbientLight;
#endif

#if defined(USE_PRIMARY_LIGHT) || defined(USE_SHADOWMAP)
	var_PrimaryLightDir.xyz = u_PrimaryLightOrigin.xyz - (position * u_PrimaryLightOrigin.w);
	var_PrimaryLightDir.w = u_PrimaryLightRadius * u_PrimaryLightRadius;
#endif

#if defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
  #if defined(USE_LIGHT_VECTOR)
	var_LightDir = vec4(L, u_LightRadius * u_LightRadius);
  #else
	var_LightDir = vec4(L, 0.0);
  #endif
  #if defined(USE_DELUXEMAP)
	var_LightDir -= u_EnableTextures.y * var_LightDir;
  #endif
#endif

#if defined(USE_LIGHT) && !defined(USE_FAST_LIGHT)
	vec3 viewDir = u_ViewOrigin - position;
  #if defined(USE_VERT_TANGENT_SPACE)
	// store view direction in tangent space to save on outs
	var_Normal    = vec4(normal,    viewDir.x);
	var_Tangent   = vec4(tangent,   viewDir.y);
	var_Bitangent = vec4(bitangent, viewDir.z);
  #else
	var_Normal = normal;
	var_ViewDir = viewDir;
  #endif
#endif
}