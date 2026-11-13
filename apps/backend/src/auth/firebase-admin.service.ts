import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { initializeApp, cert, App } from 'firebase-admin/app';
import { getAuth, DecodedIdToken } from 'firebase-admin/auth';
import * as fs from 'fs';
import * as path from 'path';
import axios from 'axios';

@Injectable()
export class FirebaseAdminService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseAdminService.name);
  private app: App;
  private apiKey: string;
  private projectId: string;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const serviceAccountPath = this.configService.get<string>(
      'FIREBASE_SERVICE_ACCOUNT_PATH',
      './firebase-service-account.json',
    );
    this.apiKey = this.configService.get<string>('FIREBASE_API_KEY', '');
    this.projectId = this.configService.get<string>('FIREBASE_PROJECT_ID', '');

    try {
      const resolvedPath = path.resolve(process.cwd(), serviceAccountPath);
      if (fs.existsSync(resolvedPath)) {
        const fileContent = fs.readFileSync(resolvedPath, 'utf8');
        const serviceAccount = JSON.parse(fileContent);

        this.app = initializeApp({
          credential: cert(serviceAccount),
          projectId: serviceAccount.project_id || this.projectId,
        });
        this.logger.log(`Firebase Admin initialized successfully for project ${serviceAccount.project_id}`);
      } else {
        this.logger.warn(`Firebase service account file not found at ${resolvedPath}`);
      }
    } catch (error) {
      this.logger.error(`Failed to initialize Firebase Admin: ${(error as Error).message}`, (error as Error).stack);
    }
  }

  async verifyIdToken(idToken: string): Promise<DecodedIdToken> {
    if (!this.app) {
      throw new Error('Firebase Admin SDK is not initialized');
    }
    return getAuth(this.app).verifyIdToken(idToken);
  }

  /**
   * Request OTP via Firebase Identity Toolkit REST API
   */
  async sendVerificationCode(phoneNumber: string): Promise<{ sessionInfo: string }> {
    if (!this.apiKey) {
      throw new Error('FIREBASE_API_KEY is not configured');
    }

    try {
      const response = await axios.post(
        `https://identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=${this.apiKey}`,
        {
          phoneNumber,
        },
      );
      return { sessionInfo: response.data.sessionInfo };
    } catch (error: any) {
      const errMsg = error.response?.data?.error?.message || error.message;
      this.logger.error(`Firebase sendVerificationCode error: ${errMsg}`);
      throw new Error(`Failed to send verification code: ${errMsg}`);
    }
  }

  /**
   * Verify OTP code via Firebase Identity Toolkit REST API
   */
  async signInWithPhoneNumber(sessionInfo: string, code: string): Promise<{ idToken: string; phoneNumber: string }> {
    if (!this.apiKey) {
      throw new Error('FIREBASE_API_KEY is not configured');
    }

    try {
      const response = await axios.post(
        `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber?key=${this.apiKey}`,
        {
          sessionInfo,
          code,
        },
      );
      return {
        idToken: response.data.idToken,
        phoneNumber: response.data.phoneNumber,
      };
    } catch (error: any) {
      const errMsg = error.response?.data?.error?.message || error.message;
      this.logger.error(`Firebase signInWithPhoneNumber error: ${errMsg}`);
      throw new Error(`Failed to verify code: ${errMsg}`);
    }
  }
}
