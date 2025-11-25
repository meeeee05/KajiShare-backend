// フロントエンドからのAPI接続テスト用サンプルコード

// ===== 基本設定 =====
const API_BASE_URL = 'http://localhost:3001';

// ===== 接続テスト =====
export const testApiConnection = async () => {
  try {
    const response = await fetch(`${API_BASE_URL}/api/test`);
    const data = await response.json();
    console.log('API Connection Test:', data);
    return data;
  } catch (error) {
    console.error('API接続エラー:', error);
    throw error;
  }
};

// ===== Google認証 =====
export const authenticateWithGoogle = async (googleIdToken) => {
  try {
    const response = await fetch(`${API_BASE_URL}/auth/google`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${googleIdToken}`,
        'Content-Type': 'application/json',
      },
      credentials: 'include', // Cookieを含める
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('認証エラー:', error);
    throw error;
  }
};

// ===== ユーザー管理 =====
export const fetchUsers = async () => {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/users`, {
      credentials: 'include',
    });
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('ユーザー取得エラー:', error);
    throw error;
  }
};

export const fetchUser = async (userId) => {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/users/${userId}`, {
      credentials: 'include',
    });
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('ユーザー詳細取得エラー:', error);
    throw error;
  }
};

export const updateUser = async (userId, userData) => {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/users/${userId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      credentials: 'include',
      body: JSON.stringify({ user: userData }),
    });
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('ユーザー更新エラー:', error);
    throw error;
  }
};

// ===== グループ管理 =====
export const fetchGroups = async () => {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/groups`, {
      credentials: 'include',
    });
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('グループ取得エラー:', error);
    throw error;
  }
};

export const createGroup = async (groupData) => {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/groups`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      credentials: 'include',
      body: JSON.stringify({ group: groupData }),
    });
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('グループ作成エラー:', error);
    throw error;
  }
};

// ===== タスク管理 =====
export const fetchGroupTasks = async (groupId) => {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/groups/${groupId}/tasks`, {
      credentials: 'include',
    });
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('タスク取得エラー:', error);
    throw error;
  }
};

export const createTask = async (groupId, taskData) => {
  try {
    const response = await fetch(`${API_BASE_URL}/api/v1/groups/${groupId}/tasks`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      credentials: 'include',
      body: JSON.stringify({ task: taskData }),
    });
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('タスク作成エラー:', error);
    throw error;
  }
};

// ===== 使用例 =====
/*
// React コンポーネント内での使用例
import { testApiConnection, authenticateWithGoogle, fetchUsers } from './api';

const App = () => {
  useEffect(() => {
    // API接続テスト
    testApiConnection()
      .then(result => console.log('API接続成功:', result))
      .catch(error => console.error('API接続失敗:', error));
  }, []);

  const handleGoogleLogin = async (googleIdToken) => {
    try {
      const result = await authenticateWithGoogle(googleIdToken);
      console.log('ログイン成功:', result);
      // ユーザー情報を状態管理に保存
    } catch (error) {
      console.error('ログイン失敗:', error);
    }
  };

  return (
    <div>
      // フロントエンドのコンポーネント
    </div>
  );
};
*/
