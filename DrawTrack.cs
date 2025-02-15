using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class DrawTrack : MonoBehaviour
{

    [SerializeField] private Material DrawMat;
    [SerializeField] private Material LandMat;

    private RenderTexture TrackRT;
    private Transform m_LastPos = null;
    public float DrawStength = 1.0f;
    public Color DrawColor = Color.white;


    // Start is called before the first frame update
    void Start()
    {
        m_LastPos = transform;

        TrackRT = new RenderTexture(2048, 2048, 0, RenderTextureFormat.Default);
        // LandMat.SetTexture("_SunkenMap", TrackRT); //设置纹理贴图
        // DrawMat.SetTexture("_TrackTex", TrackRT); //设置轨迹贴图


    }

    // Update is called once per frame
    void Update()
    {
        DrawMat.SetFloat("_DrawStength", DrawStength); //设置绘制强度
        DrawMat.SetColor("_Color", DrawColor); //设置绘制颜色
        if (Physics.Raycast(transform.position, Vector3.down, out RaycastHit hit, 10)) //z轴向下射线检测地面
        {
            DrawMat.SetVector("_Coordinate", new Vector4(hit.textureCoord.x, hit.textureCoord.y, 0, 0)); //设置纹理坐标
            RenderTexture tmp = RenderTexture.GetTemporary(TrackRT.width, TrackRT.height, 0, RenderTextureFormat.Default); //创建临时渲染纹理
            Graphics.Blit(TrackRT, tmp);
            Graphics.Blit(tmp, TrackRT, DrawMat); //绘制轨迹
            RenderTexture.ReleaseTemporary(tmp); //释放临时渲染纹理
            LandMat.SetTexture("_SunkenMap", TrackRT); //设置纹理贴图

        }
        m_LastPos.position = transform.position;

    }
}

